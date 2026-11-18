terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

locals {
  is_released   = var.tier == "released"
  is_full       = var.tier != "config"
  admin_role_id = 5
  release_tags  = ["refs/tags/v*"]

  admin_bypass = {
    actor_type  = "RepositoryRole"
    actor_id    = local.admin_role_id
    bypass_mode = "always"
  }

  standard_labels = {
    dependencies  = { color = "0366d6", description = "Pull requests that update a dependency" }
    security      = { color = "d73a4a", description = "Security fix or hardening" }
    needs-triage  = { color = "fbca04", description = "Awaiting a first look" }
    needs-info    = { color = "d876e3", description = "Waiting for details from the author" }
    blocked       = { color = "b60205", description = "Blocked by another issue or change" }
    released      = { color = "0e8a16", description = "Included in a published release" }
    held          = { color = "c5def5", description = "Update held for manual review" }
    stop-updating = { color = "e4e669", description = "Renovate stops updating this pull request" }
    breaking      = { color = "5319e7", description = "Breaking change" }
  }

  open_labels = {
    "good first issue" = { color = "7057ff", description = "Good for newcomers" }
    "help wanted"      = { color = "008672", description = "Extra attention is wanted" }
  }

  labels = merge(local.standard_labels, var.open_contributions ? local.open_labels : {}, var.extra_labels)

  ruleset_defaults = {
    target                  = "branch"
    bypass_actors           = [local.admin_bypass]
    creation                = false
    update                  = false
    deletion                = false
    non_fast_forward        = false
    required_linear_history = false
    required_signatures     = false
    pull_request            = false
    required_checks         = []
  }

  standard_rulesets = merge(
    {
      default-branch = merge(local.ruleset_defaults, {
        include                 = ["~DEFAULT_BRANCH"]
        deletion                = true
        non_fast_forward        = true
        required_signatures     = true
        required_linear_history = local.is_full
        pull_request            = local.is_full
        required_checks         = local.is_full ? [var.required_check] : []
      })
    },
    local.is_released ? {
      release-tags-creation = merge(local.ruleset_defaults, {
        target   = "tag"
        include  = local.release_tags
        creation = true
        bypass_actors = [local.admin_bypass, {
          actor_type  = "Integration"
          actor_id    = tonumber(nonsensitive(var.release_app.id))
          bypass_mode = "always"
        }]
      })
      release-tags-immutable = merge(local.ruleset_defaults, {
        target           = "tag"
        include          = local.release_tags
        bypass_actors    = []
        update           = true
        deletion         = true
        non_fast_forward = true
      })
    } : {},
  )

  extra_rulesets = {
    for name, r in var.extra_rulesets : name => merge(local.ruleset_defaults, r, {
      bypass_actors = concat([local.admin_bypass], [for id in r.bypass_integration_ids : {
        actor_type  = "Integration"
        actor_id    = id
        bypass_mode = "always"
      }])
    })
  }

  rulesets = merge(local.standard_rulesets, local.extra_rulesets)

  release_secrets = local.is_released ? toset(["RELEASE_APP_ID", "RELEASE_APP_PRIVATE_KEY"]) : toset([])
}

resource "github_repository" "this" {
  name                        = var.name
  has_issues                  = true
  has_wiki                    = false
  has_projects                = false
  has_discussions             = local.is_released
  allow_merge_commit          = false
  allow_rebase_merge          = false
  allow_squash_merge          = true
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "BLANK"
  delete_branch_on_merge      = true
  allow_auto_merge            = true
  allow_update_branch         = true
  archive_on_destroy          = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [description, homepage_url]
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "this" {
  repository = github_repository.this.name
  enabled    = true
  depends_on = [github_repository_vulnerability_alerts.this]
}

resource "github_actions_repository_permissions" "this" {
  repository           = github_repository.this.name
  enabled              = true
  allowed_actions      = "all"
  sha_pinning_required = true
}

resource "github_workflow_repository_permissions" "this" {
  repository                       = github_repository.this.name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false
}

resource "github_repository_ruleset" "this" {
  for_each    = local.rulesets
  repository  = github_repository.this.name
  name        = each.key
  target      = each.value.target
  enforcement = "active"

  conditions {
    ref_name {
      include = each.value.include
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = each.value.bypass_actors
    content {
      actor_type  = bypass_actors.value.actor_type
      actor_id    = bypass_actors.value.actor_id
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    creation                = each.value.creation
    update                  = each.value.update
    deletion                = each.value.deletion
    non_fast_forward        = each.value.non_fast_forward
    required_linear_history = each.value.required_linear_history
    required_signatures     = each.value.required_signatures

    dynamic "pull_request" {
      for_each = each.value.pull_request ? [true] : []
      content {
        allowed_merge_methods           = ["squash"]
        required_approving_review_count = 0
      }
    }

    dynamic "required_status_checks" {
      for_each = length(each.value.required_checks) > 0 ? [each.value.required_checks] : []
      content {
        dynamic "required_check" {
          for_each = required_status_checks.value
          content {
            context = required_check.value
          }
        }
      }
    }
  }
}

resource "github_issue_label" "this" {
  for_each    = local.labels
  repository  = github_repository.this.name
  name        = each.key
  color       = each.value.color
  description = each.value.description
}

resource "github_actions_secret" "release_app" {
  for_each    = local.release_secrets
  repository  = github_repository.this.name
  secret_name = each.key
  value       = { RELEASE_APP_ID = var.release_app.id, RELEASE_APP_PRIVATE_KEY = var.release_app.private_key }[each.key]
}
