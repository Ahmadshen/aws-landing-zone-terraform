mock_provider "aws" {}

variables {
  log_bucket_name     = "example-org-logs"
  kms_key_arn         = "arn:aws:kms:us-east-1:444444444444:key/11111111-2222-3333-4444-555555555555"
  security_account_id = "333333333333"
}

run "org_trail_is_hardened" {
  command = apply

  assert {
    condition = alltrue([
      aws_cloudtrail.org.is_organization_trail,
      aws_cloudtrail.org.is_multi_region_trail,
      aws_cloudtrail.org.enable_log_file_validation,
      aws_cloudtrail.org.include_global_service_events,
    ])
    error_message = "Org trail must be organization-wide, multi-region, validated and include global events."
  }

  assert {
    condition     = aws_cloudtrail.org.kms_key_id == var.kms_key_arn
    error_message = "Org trail must be KMS-encrypted."
  }

  assert {
    condition     = aws_guardduty_organization_admin_account.this[0].admin_account_id == "333333333333"
    error_message = "GuardDuty admin must be the security account."
  }
}

run "services_can_be_switched_off" {
  command = apply

  variables {
    enable_guardduty         = false
    enable_securityhub       = false
    enable_access_analyzer   = false
    enable_config_delegation = false
  }

  assert {
    condition = (
      length(aws_guardduty_organization_admin_account.this) +
      length(aws_securityhub_organization_admin_account.this) +
      length(aws_organizations_delegated_administrator.access_analyzer) +
      length(aws_organizations_delegated_administrator.config)
    ) == 0
    error_message = "Disabled services must not create resources."
  }
}
