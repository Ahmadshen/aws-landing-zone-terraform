mock_provider "aws" {
  mock_resource "aws_organizations_organization" {
    defaults = {
      id                = "o-exampleorgid"
      master_account_id = "111111111111"
      roots             = [{ id = "r-root", arn = "arn:aws:organizations::111111111111:root/o-exampleorgid/r-root", name = "Root", policy_types = [] }]
    }
  }

  # OU IDs must match the provider's ou-xxxx-xxxxxxxx format to be valid parents.
  mock_resource "aws_organizations_organizational_unit" {
    defaults = {
      id = "ou-abcd-12345678"
    }
  }
}

variables {
  organizational_units = {
    security          = { name = "Security" }
    workloads         = { name = "Workloads" }
    workloads_prod    = { name = "Prod", parent = "workloads" }
    workloads_nonprod = { name = "NonProd", parent = "workloads" }
  }
}

run "creates_two_level_hierarchy" {
  command = apply

  assert {
    condition     = length(aws_organizations_organizational_unit.top) == 2
    error_message = "Expected 2 top-level OUs."
  }

  assert {
    condition     = length(aws_organizations_organizational_unit.child) == 2
    error_message = "Expected 2 child OUs."
  }

  assert {
    condition     = aws_organizations_organizational_unit.top["security"].parent_id == "r-root"
    error_message = "Top-level OUs must hang off the organization root."
  }

  assert {
    condition     = aws_organizations_organizational_unit.child["workloads_prod"].parent_id == aws_organizations_organizational_unit.top["workloads"].id
    error_message = "Child OUs must hang off their parent OU."
  }

  assert {
    condition     = length(output.ou_ids) == 4
    error_message = "ou_ids must expose every OU."
  }
}

run "rejects_three_levels" {
  command = plan

  variables {
    organizational_units = {
      a = { name = "A" }
      b = { name = "B", parent = "a" }
      c = { name = "C", parent = "b" }
    }
  }

  expect_failures = [var.organizational_units]
}
