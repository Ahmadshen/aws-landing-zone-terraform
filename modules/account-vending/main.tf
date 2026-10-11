resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name              = each.key
  email             = each.value.email
  parent_id         = each.value.ou_id
  role_name         = var.access_role_name
  close_on_deletion = false
  tags              = merge(var.tags, each.value.tags)

  # AWS does not return role_name after creation; changing it would force a new account.
  lifecycle {
    ignore_changes = [role_name]
  }
}
