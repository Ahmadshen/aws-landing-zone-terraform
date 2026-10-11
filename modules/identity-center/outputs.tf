output "permission_set_arns" {
  value = { for k, ps in aws_ssoadmin_permission_set.this : k => ps.arn }
}

output "group_ids" {
  value = { for k, g in aws_identitystore_group.this : k => g.group_id }
}

output "instance_arn" {
  value = local.instance_arn
}
