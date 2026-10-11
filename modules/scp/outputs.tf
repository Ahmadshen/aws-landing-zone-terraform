output "policy_ids" {
  description = "SCP IDs keyed by guardrail name."
  value       = { for k, p in aws_organizations_policy.this : k => p.id }
}

output "policy_documents" {
  description = "Rendered SCP JSON keyed by guardrail name (useful for review and size checks)."
  value       = { for k, p in aws_organizations_policy.this : k => p.content }
}
