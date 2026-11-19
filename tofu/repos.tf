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

module "blog" {
  source          = "./modules/standard"
  name            = "blog"
  tier            = "deployed"
  required_check  = "ci-gate"
  has_discussions = true
}

import {
  to = module.blog.github_repository.this
  id = "blog"
}

import {
  to = module.blog.github_issue_label.this["dependencies"]
  id = "blog:dependencies"
}

module "horizon" {
  source             = "./modules/standard"
  name               = "horizon"
  tier               = "released"
  required_check     = "ci-gate"
  release_app        = local.release_app
  open_contributions = true
}

import {
  to = module.horizon.github_repository.this
  id = "horizon"
}

import {
  to = module.horizon.github_repository_ruleset.this["default-branch"]
  id = "horizon:17506885"
}

import {
  to = module.horizon.github_issue_label.this["dependencies"]
  id = "horizon:dependencies"
}

import {
  to = module.horizon.github_issue_label.this["good first issue"]
  id = "horizon:good first issue"
}

import {
  to = module.horizon.github_issue_label.this["help wanted"]
  id = "horizon:help wanted"
}

module "bedrock" {
  source         = "./modules/standard"
  name           = "bedrock"
  tier           = "deployed"
  required_check = "ci-gate"

  extra_labels = {
    kubernetes    = { color = "326ce5", description = "Changes under kubernetes/" }
    hosts         = { color = "bfd4f2", description = "Changes under hosts/" }
    nix           = { color = "7ebae4", description = "Changes under modules/" }
    documentation = { color = "0075ca", description = "Improvements or additions to documentation" }
    ci            = { color = "fef2c0", description = "Changes under .github/" }
  }
}

import {
  to = module.bedrock.github_repository.this
  id = "bedrock"
}

import {
  to = module.bedrock.github_repository_ruleset.this["default-branch"]
  id = "bedrock:17505962"
}

import {
  to = module.bedrock.github_issue_label.this["dependencies"]
  id = "bedrock:dependencies"
}

import {
  to = module.bedrock.github_issue_label.this["held"]
  id = "bedrock:held"
}

import {
  to = module.bedrock.github_issue_label.this["documentation"]
  id = "bedrock:documentation"
}
