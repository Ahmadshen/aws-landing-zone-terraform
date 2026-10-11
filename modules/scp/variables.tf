variable "name_prefix" {
  description = "Prefix for SCP names."
  type        = string
  default     = "lz"
}

variable "attachments" {
  description = <<-EOT
    Map of guardrail name => { label => target ID } (root, OU or account IDs).
    Labels are static names used as resource keys, so IDs may be unknown at plan time.
    Available guardrails: deny_leave_organization, deny_root_user, region_allowlist,
    protect_security_services, require_imdsv2. Only listed guardrails are created.
  EOT
  type        = map(map(string))

  validation {
    condition = alltrue([for k in keys(var.attachments) : contains([
      "deny_leave_organization", "deny_root_user", "region_allowlist", "protect_security_services", "require_imdsv2",
    ], k)])
    error_message = "Unknown guardrail name in attachments."
  }
}

variable "allowed_regions" {
  description = "Regions where regional services may be used (region_allowlist guardrail)."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "exempt_principal_arns" {
  description = "Role ARN patterns allowed to bypass region and security-service guardrails (break-glass, pipeline roles)."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
