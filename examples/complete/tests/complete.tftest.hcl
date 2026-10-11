# Wires every module together against mocked AWS accounts: no credentials needed.

mock_provider "aws" {
  mock_resource "aws_organizations_organization" {
    defaults = {
      id                = "o-exampleorg1"
      master_account_id = "111111111111"
      roots             = [{ id = "r-root", arn = "arn:aws:organizations::111111111111:root/o-exampleorg1/r-root", name = "Root", policy_types = [] }]
    }
  }
  mock_resource "aws_organizations_organizational_unit" {
    defaults = { id = "ou-abcd-12345678" }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "555555555555" }
  }
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-1234567890abcdef"]
      identity_store_ids = ["d-1234567890"]
    }
  }
  mock_resource "aws_identitystore_group" {
    defaults = { group_id = "9067c2e4f1-11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = { arn = "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-1234567890abcdef" }
  }
}

mock_provider "aws" {
  alias = "log_archive"
  mock_data "aws_caller_identity" {
    defaults = { account_id = "444444444444" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { id = "acme-org-cloudtrail-logs", arn = "arn:aws:s3:::acme-org-cloudtrail-logs" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:444444444444:key/11111111-2222-3333-4444-555555555555" }
  }
}

variables {
  security_account_id    = "333333333333"
  log_archive_account_id = "444444444444"
  log_bucket_name        = "acme-org-cloudtrail-logs"
  workload_accounts = {
    payments-prod    = { email = "aws+payments-prod@acme.example", ou = "workloads_prod" }
    payments-staging = { email = "aws+payments-staging@acme.example", ou = "workloads_nonprod" }
  }
}

run "full_landing_zone" {
  command = apply

  assert {
    condition     = length(output.ou_ids) == 7
    error_message = "Expected 7 OUs."
  }

  assert {
    condition     = length(output.workload_account_ids) == 2
    error_message = "Expected 2 vended workload accounts."
  }

  # 1 root (leave) + 1 root (protect) + 3 OUs (root user) + 2 OUs (regions) + 1 OU (IMDSv2)
  assert {
    condition     = length(module.guardrails.policy_ids) == 5
    error_message = "All five guardrails should be active."
  }

  # admins x2 + engineers x2 + security-audit x4 (2 workloads + security + log archive)
  assert {
    condition     = length(module.identity_center.permission_set_arns) == 4
    error_message = "Expected 4 permission sets."
  }

  assert {
    condition     = output.org_trail_arn != null
    error_message = "Org trail must be created."
  }
}

run "rejects_unknown_workload_ou" {
  command = plan

  variables {
    workload_accounts = { bad = { email = "aws+bad@acme.example", ou = "sandbox" } }
  }

  expect_failures = [var.workload_accounts]
}
