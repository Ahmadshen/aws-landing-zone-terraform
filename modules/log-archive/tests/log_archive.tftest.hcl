mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "444444444444" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::example-org-logs" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:444444444444:key/11111111-2222-3333-4444-555555555555" }
  }
}

variables {
  bucket_name           = "example-org-logs"
  management_account_id = "111111111111"
  organization_id       = "o-exampleorg1"
  trail_region          = "us-east-1"
}

run "locks_down_the_bucket" {
  command = apply

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.logs.block_public_acls,
      aws_s3_bucket_public_access_block.logs.block_public_policy,
      aws_s3_bucket_public_access_block.logs.ignore_public_acls,
      aws_s3_bucket_public_access_block.logs.restrict_public_buckets,
    ])
    error_message = "All four public access blocks must be on."
  }

  assert {
    condition     = aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled."
  }

  assert {
    condition     = aws_kms_key.cloudtrail.enable_key_rotation
    error_message = "KMS key rotation must be enabled."
  }

  assert {
    condition = contains(
      [for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement : s.Sid],
      "DenyInsecureTransport",
    )
    error_message = "Bucket policy must deny non-TLS access."
  }

  assert {
    condition = contains(
      [for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement : s if s.Sid == "CloudTrailWrite"][0].Resource,
      "arn:aws:s3:::example-org-logs/AWSLogs/o-exampleorg1/*",
    )
    error_message = "CloudTrail must be able to write organization-scoped log paths."
  }

  assert {
    condition     = [for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement : s if s.Sid == "CloudTrailWrite"][0].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:us-east-1:111111111111:trail/org-trail"
    error_message = "Writes must be scoped to the org trail ARN (confused-deputy protection)."
  }
}

run "rejects_bad_org_id" {
  command = plan

  variables {
    organization_id = "not-an-org"
  }

  expect_failures = [var.organization_id]
}
