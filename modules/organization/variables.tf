variable "aws_service_access_principals" {
  description = "AWS services trusted to integrate with the organization."
  type        = list(string)
  default = [
    "access-analyzer.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]
}

variable "organizational_units" {
  description = <<-EOT
    OUs keyed by a stable identifier. `parent` is the key of another OU in this
    map (one level of nesting), or null for an OU directly under the root.
  EOT
  type = map(object({
    name   = string
    parent = optional(string)
    tags   = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, ou in var.organizational_units :
      ou.parent == null ? true : try(var.organizational_units[ou.parent].parent == null, false)
    ])
    error_message = "Each `parent` must reference a top-level OU key in this map (max two levels)."
  }
}
