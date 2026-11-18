variable "release_app_id" {
  type      = string
  sensitive = true
}

variable "release_app_private_key" {
  type      = string
  sensitive = true
}

locals {
  release_app = {
    id          = var.release_app_id
    private_key = var.release_app_private_key
  }
}

module "dotgithub" {
  source         = "./modules/standard"
  name           = ".github"
  tier           = "released"
  required_check = "ci-gate"
  release_app    = local.release_app
}

import {
  to = module.dotgithub.github_repository.this
  id = ".github"
}
