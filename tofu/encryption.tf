variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "The state passphrase must be at least 16 characters."
  }
}

terraform {
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method   = method.aes_gcm.passphrase
      enforced = true
    }

    plan {
      method   = method.aes_gcm.passphrase
      enforced = true
    }
  }
}
