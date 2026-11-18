variable "name" {
  type = string
}

variable "tier" {
  type = string

  validation {
    condition     = contains(["released", "deployed", "config"], var.tier)
    error_message = "The tier must be released, deployed or config."
  }
}

variable "required_check" {
  type    = string
  default = null

  validation {
    condition     = var.tier == "config" || var.required_check != null
    error_message = "Released and deployed repos need one required aggregate check."
  }

  validation {
    condition     = var.required_check == null ? true : trimspace(var.required_check) != ""
    error_message = "The required check must be a non-empty check name."
  }
}

variable "extra_labels" {
  type = map(object({
    color       = string
    description = string
  }))
  default = {}
}

variable "extra_rulesets" {
  type = map(object({
    target                  = optional(string, "branch")
    include                 = list(string)
    bypass_integration_ids  = optional(list(number), [])
    creation                = optional(bool, false)
    update                  = optional(bool, false)
    deletion                = optional(bool, false)
    non_fast_forward        = optional(bool, false)
    required_linear_history = optional(bool, false)
    required_signatures     = optional(bool, false)
    required_checks         = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.extra_rulesets) : contains(["branch", "tag"], r.target)])
    error_message = "An extra ruleset must target branch or tag."
  }
}

variable "open_contributions" {
  type    = bool
  default = false
}

variable "release_app" {
  type = object({
    id          = string
    private_key = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = (var.tier == "released") == (var.release_app != null)
    error_message = "The release App is required for released repos and only for them."
  }
}
