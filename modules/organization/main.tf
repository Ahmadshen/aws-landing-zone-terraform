resource "aws_organizations_organization" "this" {
  feature_set                   = "ALL"
  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id

  # Two levels are enough for almost every landing zone (e.g. Workloads -> Prod).
  top_level_ous = { for k, ou in var.organizational_units : k => ou if ou.parent == null }
  child_ous     = { for k, ou in var.organizational_units : k => ou if ou.parent != null }
}

resource "aws_organizations_organizational_unit" "top" {
  for_each = local.top_level_ous

  name      = each.value.name
  parent_id = local.root_id
  tags      = each.value.tags
}

resource "aws_organizations_organizational_unit" "child" {
  for_each = local.child_ous

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.top[each.value.parent].id
  tags      = each.value.tags
}
