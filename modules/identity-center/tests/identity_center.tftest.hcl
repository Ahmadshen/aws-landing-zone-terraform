mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-1234567890abcdef"]
      identity_store_ids = ["d-1234567890"]
    }
  }

  # Group IDs must look like real Identity Store IDs to pass provider validation.
  mock_resource "aws_identitystore_group" {
    defaults = {
      group_id = "9067c2e4f1-11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "aws_ssoadmin_permission_set" {
    defaults = {
      arn = "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-1234567890abcdef"
    }
  }
}

variables {
  permission_sets = {
    AdministratorAccess = {
      description         = "Full admin, break-glass use only"
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
    ReadOnly = {
      description         = "Read-only for engineers"
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess", "arn:aws:iam::aws:policy/AWSSupportAccess"]
      inline_policy       = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}"
    }
  }
  groups = {
    platform-admins = "Platform team"
    engineers       = "All engineers"
  }
  account_assignments = [
    { group = "platform-admins", permission_set = "AdministratorAccess", account_name = "prod", account_id = "222222222222" },
    { group = "engineers", permission_set = "ReadOnly", account_name = "prod", account_id = "222222222222" },
    { group = "engineers", permission_set = "ReadOnly", account_name = "staging", account_id = "333333333333" },
  ]
}

run "creates_permission_sets_groups_and_assignments" {
  command = apply

  assert {
    condition     = length(aws_ssoadmin_managed_policy_attachment.this) == 3
    error_message = "Expected one attachment per managed policy."
  }

  assert {
    condition     = keys(aws_ssoadmin_permission_set_inline_policy.this) == ["ReadOnly"]
    error_message = "Only permission sets with an inline policy should get one."
  }

  assert {
    condition     = length(aws_ssoadmin_account_assignment.this) == 3
    error_message = "Expected three account assignments."
  }

  assert {
    condition     = aws_ssoadmin_permission_set.this["ReadOnly"].session_duration == "PT4H"
    error_message = "Session duration should default to PT4H."
  }

  assert {
    condition     = alltrue([for a in aws_ssoadmin_account_assignment.this : a.principal_type == "GROUP"])
    error_message = "Access must be granted to groups, never individual users."
  }
}

run "rejects_long_sessions" {
  command = plan

  variables {
    permission_sets = {
      TooLong = { description = "x", session_duration = "PT24H" }
    }
    account_assignments = []
  }

  expect_failures = [var.permission_sets]
}

run "rejects_bad_account_id" {
  command = plan

  variables {
    account_assignments = [{ group = "engineers", permission_set = "ReadOnly", account_name = "bad", account_id = "1234" }]
  }

  expect_failures = [var.account_assignments]
}
