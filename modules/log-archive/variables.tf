variable "bucket_name" {
  description = "Globally unique name for the log archive bucket."
  type        = string
}

variable "management_account_id" {
  description = "Account ID of the organization management account (owns the org trail)."
  type        = string
}

variable "organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx)."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must look like o-xxxxxxxxxx."
  }
}

variable "trail_name" {
  description = "Name of the organization trail that will write here."
  type        = string
  default     = "org-trail"
}

variable "trail_region" {
  description = "Home region of the organization trail."
  type        = string
}

variable "glacier_after_days" {
  type    = number
  default = 90
}

variable "retention_days" {
  description = "Delete logs after this many days."
  type        = number
  default     = 2555 # ~7 years

  validation {
    condition     = var.retention_days > var.glacier_after_days
    error_message = "retention_days must be greater than glacier_after_days."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
