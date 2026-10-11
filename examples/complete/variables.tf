variable "home_region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_regions" {
  type    = list(string)
  default = ["us-east-1", "eu-west-1"]
}

variable "security_account_id" {
  description = "Existing security tooling account (bootstrap it before this stack)."
  type        = string
}

variable "log_archive_account_id" {
  description = "Existing log archive account (bootstrap it before this stack)."
  type        = string
}

variable "log_bucket_name" {
  type = string
}

variable "break_glass_role_name" {
  description = "Role exempt from region and security-service guardrails."
  type        = string
  default     = "BreakGlassAdmin"
}

variable "workload_accounts" {
  description = "Workload accounts to vend: name => { email, ou } where ou is workloads_prod or workloads_nonprod."
  type = map(object({
    email = string
    ou    = string
  }))
  default = {}

  validation {
    condition     = alltrue([for a in values(var.workload_accounts) : contains(["workloads_prod", "workloads_nonprod"], a.ou)])
    error_message = "ou must be workloads_prod or workloads_nonprod."
  }
}
