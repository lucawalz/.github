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

module "dotfiles" {
  source         = "./modules/standard"
  name           = "dotfiles"
  tier           = "config"
  required_check = "ci-gate"
}

import {
  to = module.dotfiles.github_repository.this
  id = "dotfiles"
}

import {
  to = module.dotfiles.github_issue_label.this["dependencies"]
  id = "dotfiles:dependencies"
}

module "lucawalz" {
  source = "./modules/standard"
  name   = "lucawalz"
  tier   = "config"
}

import {
  to = module.lucawalz.github_repository.this
  id = "lucawalz"
}
