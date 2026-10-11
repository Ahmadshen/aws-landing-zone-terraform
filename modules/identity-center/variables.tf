variable "permission_sets" {
  description = "Permission sets keyed by name."
  type = map(object({
    description         = string
    session_duration    = optional(string, "PT4H")
    managed_policy_arns = optional(list(string), [])
    inline_policy       = optional(string)
  }))

  validation {
    condition     = alltrue([for ps in values(var.permission_sets) : can(regex("^PT([1-9]|1[0-2])H$", ps.session_duration))])
    error_message = "session_duration must be between PT1H and PT12H."
  }
}

variable "groups" {
  description = "Identity Center groups: display name => description."
  type        = map(string)
}

variable "account_assignments" {
  description = "Which group gets which permission set in which account."
  type = list(object({
    group          = string
    permission_set = string
    account_name   = string # static key; account_id may be unknown until apply
    account_id     = string
  }))
  default = []

  validation {
    condition     = alltrue([for a in var.account_assignments : can(regex("^[0-9]{12}$", a.account_id))])
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
