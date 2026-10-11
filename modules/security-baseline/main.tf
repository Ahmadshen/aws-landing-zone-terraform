# Runs in the organization management account.

resource "aws_cloudtrail" "org" {
  name                          = var.trail_name
  s3_bucket_name                = var.log_bucket_name
  kms_key_id                    = var.kms_key_arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  tags                          = var.tags
}

# Hand day-to-day security tooling to the dedicated security account, so the
# management account stays empty of workloads and humans.
resource "aws_guardduty_organization_admin_account" "this" {
  count            = var.enable_guardduty ? 1 : 0
  admin_account_id = var.security_account_id
}

resource "aws_securityhub_account" "management" {
  count = var.enable_securityhub ? 1 : 0
}

resource "aws_securityhub_organization_admin_account" "this" {
  count            = var.enable_securityhub ? 1 : 0
  admin_account_id = var.security_account_id

  depends_on = [aws_securityhub_account.management]
}

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  count             = var.enable_access_analyzer ? 1 : 0
  account_id        = var.security_account_id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "config" {
  count             = var.enable_config_delegation ? 1 : 0
  account_id        = var.security_account_id
  service_principal = "config.amazonaws.com"
}
