variable "accounts" {
  description = "Accounts to create, keyed by account name."
  type = map(object({
    email = string
    ou_id = string
    tags  = optional(map(string), {})
  }))

  validation {
    condition     = alltrue([for a in values(var.accounts) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", a.email))])
    error_message = "Every account needs a valid root email address."
  }

  validation {
    condition     = length(distinct([for a in values(var.accounts) : lower(a.email)])) == length(var.accounts)
    error_message = "Account emails must be unique (AWS requires one email per account)."
  }
}

variable "access_role_name" {
  description = "Role created in each new account that the management account can assume."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "tags" {
  type    = map(string)
  default = {}
}
