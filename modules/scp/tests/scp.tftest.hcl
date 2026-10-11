mock_provider "aws" {}

variables {
  allowed_regions       = ["eu-west-1", "us-east-1"]
  exempt_principal_arns = ["arn:aws:iam::*:role/BreakGlass"]
  attachments = {
    deny_leave_organization   = { root = "r-root" }
    deny_root_user            = { workloads = "ou-abcd-11111111" }
    region_allowlist          = { workloads = "ou-abcd-11111111", sandbox = "ou-abcd-22222222" }
    protect_security_services = { root = "r-root" }
    require_imdsv2            = { sandbox = "ou-abcd-22222222" }
  }
}

run "renders_and_attaches_guardrails" {
  command = apply

  assert {
    condition     = length(aws_organizations_policy.this) == 5
    error_message = "All five guardrails should be created."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.this) == 6
    error_message = "Expected one attachment per (guardrail, target) pair."
  }

  assert {
    condition     = jsondecode(output.policy_documents["region_allowlist"]).Statement[0].Condition.StringNotEquals["aws:RequestedRegion"] == ["eu-west-1", "us-east-1"]
    error_message = "Region allowlist must use the configured regions."
  }

  assert {
    condition     = jsondecode(output.policy_documents["region_allowlist"]).Statement[0].Condition.ArnNotLike["aws:PrincipalArn"] == ["arn:aws:iam::*:role/BreakGlass"]
    error_message = "Break-glass roles must be exempt from the region allowlist."
  }

  assert {
    condition     = contains(jsondecode(output.policy_documents["protect_security_services"]).Statement[0].Action, "cloudtrail:StopLogging")
    error_message = "CloudTrail must be protected."
  }

  # AWS rejects SCPs over 5,120 characters.
  assert {
    condition     = alltrue([for doc in values(output.policy_documents) : length(doc) <= 5120])
    error_message = "An SCP exceeds the 5,120-character limit."
  }
}

run "only_requested_guardrails_are_created" {
  command = apply

  variables {
    attachments = { deny_root_user = { root = "r-root" } }
  }

  assert {
    condition     = keys(aws_organizations_policy.this) == ["deny_root_user"]
    error_message = "Unrequested guardrails must not be created."
  }
}

run "no_null_conditions_without_exemptions" {
  command = apply

  variables {
    exempt_principal_arns = []
  }

  assert {
    condition     = alltrue([for doc in values(output.policy_documents) : !strcontains(doc, "null")])
    error_message = "Rendered SCPs must not contain null values (AWS rejects them)."
  }
}

run "rejects_unknown_guardrail" {
  command = plan

  variables {
    attachments = { allow_everything = { root = "r-root" } }
  }

  expect_failures = [var.attachments]
}
