locals {
  tags = { ManagedBy = "terraform", Stack = "landing-zone" }
}

module "organization" {
  source = "../../modules/organization"

  organizational_units = {
    security          = { name = "Security" }
    infrastructure    = { name = "Infrastructure" }
    workloads         = { name = "Workloads" }
    workloads_prod    = { name = "Prod", parent = "workloads" }
    workloads_nonprod = { name = "NonProd", parent = "workloads" }
    sandbox           = { name = "Sandbox" }
    suspended         = { name = "Suspended" }
  }
}

module "accounts" {
  source = "../../modules/account-vending"

  accounts = {
    for name, a in var.workload_accounts : name => {
      email = a.email
      ou_id = module.organization.ou_ids[a.ou]
      tags  = { Environment = a.ou == "workloads_prod" ? "prod" : "nonprod" }
    }
  }
}

module "guardrails" {
  source = "../../modules/scp"

  allowed_regions       = var.allowed_regions
  exempt_principal_arns = ["arn:aws:iam::*:role/${var.break_glass_role_name}"]

  attachments = {
    deny_leave_organization   = { root = module.organization.root_id }
    protect_security_services = { root = module.organization.root_id }
    deny_root_user = {
      for ou in ["workloads", "sandbox", "infrastructure"] : ou => module.organization.ou_ids[ou]
    }
    region_allowlist = {
      for ou in ["workloads", "sandbox"] : ou => module.organization.ou_ids[ou]
    }
    require_imdsv2 = { workloads = module.organization.ou_ids["workloads"] }
  }

}

module "identity_center" {
  source = "../../modules/identity-center"

  groups = {
    platform-admins = "Platform team: admin access"
    engineers       = "All engineers"
    security-audit  = "Security team: read-only everywhere"
  }

  permission_sets = {
    AdministratorAccess = {
      description         = "Full admin, short sessions"
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
    PowerUser = {
      description         = "Build and run workloads, no IAM changes"
      managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    }
    ReadOnly = {
      description         = "Read-only"
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
    SecurityAudit = {
      description         = "Security review"
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
    }
  }

  account_assignments = concat(
    [for name, id in module.accounts.account_ids : {
      group = "platform-admins", permission_set = "AdministratorAccess", account_name = name, account_id = id
    }],
    [for name, id in module.accounts.account_ids : {
      group          = "engineers"
      permission_set = var.workload_accounts[name].ou == "workloads_prod" ? "ReadOnly" : "PowerUser"
      account_name   = name
      account_id     = id
    }],
    [for name, id in merge(module.accounts.account_ids, { security = var.security_account_id, log-archive = var.log_archive_account_id }) : {
      group = "security-audit", permission_set = "SecurityAudit", account_name = name, account_id = id
    }],
  )

}

module "log_archive" {
  source    = "../../modules/log-archive"
  providers = { aws = aws.log_archive }

  bucket_name           = var.log_bucket_name
  management_account_id = module.organization.management_account_id
  organization_id       = module.organization.organization_id
  trail_region          = var.home_region
}

module "security_baseline" {
  source = "../../modules/security-baseline"

  log_bucket_name     = module.log_archive.bucket_name
  kms_key_arn         = module.log_archive.kms_key_arn
  security_account_id = var.security_account_id

  # The bucket policy must exist before CloudTrail validates write access.
  depends_on = [module.log_archive]
}
