variable "trail_name" {
  type    = string
  default = "org-trail"
}

variable "log_bucket_name" {
  description = "Bucket created by the log-archive module."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key created by the log-archive module."
  type        = string
}

variable "security_account_id" {
  description = "Account that becomes delegated admin for security services."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "security_account_id must be a 12-digit AWS account ID."
  }
}

variable "enable_guardduty" {
  type    = bool
  default = true
}

variable "enable_securityhub" {
  type    = bool
  default = true
}

variable "enable_access_analyzer" {
  type    = bool
  default = true
}

variable "enable_config_delegation" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
