mock_provider "aws" {}

variables {
  tags = { ManagedBy = "terraform" }
  accounts = {
    security    = { email = "aws+security@example.com", ou_id = "ou-abcd-11111111" }
    log-archive = { email = "aws+logs@example.com", ou_id = "ou-abcd-11111111" }
    workload-prod = {
      email = "aws+prod@example.com"
      ou_id = "ou-abcd-22222222"
      tags  = { Environment = "prod" }
    }
  }
}

run "vends_accounts_safely" {
  command = apply

  assert {
    condition     = length(aws_organizations_account.this) == 3
    error_message = "Expected three accounts."
  }

  assert {
    condition     = alltrue([for a in aws_organizations_account.this : a.close_on_deletion == false])
    error_message = "Removing an account from code must never close the real account."
  }

  assert {
    condition     = aws_organizations_account.this["workload-prod"].tags == tomap({ ManagedBy = "terraform", Environment = "prod" })
    error_message = "Per-account tags must merge with module tags."
  }
}

run "rejects_duplicate_emails" {
  command = plan

  variables {
    accounts = {
      a = { email = "aws@example.com", ou_id = "ou-abcd-11111111" }
      b = { email = "AWS@example.com", ou_id = "ou-abcd-11111111" }
    }
  }

  expect_failures = [var.accounts]
}
