output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "root_id" {
  value = local.root_id
}

output "management_account_id" {
  value = aws_organizations_organization.this.master_account_id
}

output "ou_ids" {
  description = "OU IDs keyed by the same keys as var.organizational_units."
  value = merge(
    { for k, ou in aws_organizations_organizational_unit.top : k => ou.id },
    { for k, ou in aws_organizations_organizational_unit.child : k => ou.id },
  )
}
