output "organization_id" {
  value = module.organization.organization_id
}

output "ou_ids" {
  value = module.organization.ou_ids
}

output "workload_account_ids" {
  value = module.accounts.account_ids
}

output "org_trail_arn" {
  value = module.security_baseline.trail_arn
}
