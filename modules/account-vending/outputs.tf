output "account_ids" {
  value = { for k, a in aws_organizations_account.this : k => a.id }
}
