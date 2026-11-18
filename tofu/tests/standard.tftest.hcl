mock_provider "github" {}

variables {
  state_passphrase            = "test-passphrase-not-a-secret"
  release_app_id              = "123"
  release_app_private_key     = "test-key"
  name                        = "example"
  required_check              = "ci-gate"
  release_app                 = { id = "123", private_key = "test-key" }
  standard_labels_count       = 9
  open_contribution_labels    = ["good first issue", "help wanted"]
  default_branch_rule_summary = ["deletion", "non_fast_forward", "required_linear_history", "required_signatures"]
}

run "released_repo" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier = "released"
  }

  assert {
    condition     = [for a in github_repository_ruleset.this["release-tags-creation"].bypass_actors : "${a.actor_type}:${a.actor_id}"] == ["RepositoryRole:5", "Integration:123"]
    error_message = "the tag creation ruleset bypass actors must be exactly the admin role and the release App"
  }

  assert {
    condition     = github_repository_ruleset.this["release-tags-creation"].target == "tag" && github_repository_ruleset.this["release-tags-creation"].conditions[0].ref_name[0].include == tolist(["refs/tags/v*"])
    error_message = "the tag creation ruleset must target v* tags"
  }

  assert {
    condition     = length(github_repository_ruleset.this["release-tags-immutable"].bypass_actors) == 0 && github_repository_ruleset.this["release-tags-immutable"].rules[0].update && github_repository_ruleset.this["release-tags-immutable"].rules[0].deletion
    error_message = "v* tags must not be updatable or deletable by anyone"
  }

  assert {
    condition     = [for a in github_repository_ruleset.this["default-branch"].bypass_actors : "${a.actor_type}:${a.actor_id}:${a.bypass_mode}"] == ["RepositoryRole:5:always"]
    error_message = "the default-branch ruleset must keep the admin as its only bypass actor"
  }

  assert {
    condition = alltrue([
      github_repository_ruleset.this["default-branch"].rules[0].required_signatures,
      github_repository_ruleset.this["default-branch"].rules[0].non_fast_forward,
      github_repository_ruleset.this["default-branch"].rules[0].deletion,
      github_repository_ruleset.this["default-branch"].rules[0].required_linear_history,
    ])
    error_message = "the default-branch ruleset must require signatures and linear history and block force pushes and deletion"
  }

  assert {
    condition     = [for c in github_repository_ruleset.this["default-branch"].rules[0].required_status_checks[0].required_check : c.context] == ["ci-gate"]
    error_message = "the default-branch ruleset must require exactly the declared check"
  }

  assert {
    condition     = github_repository_ruleset.this["default-branch"].rules[0].pull_request[0].required_approving_review_count == 0 && github_repository_ruleset.this["default-branch"].rules[0].pull_request[0].allowed_merge_methods == tolist(["squash"])
    error_message = "the default-branch ruleset must require a squash-merged PR with zero approvals"
  }

  assert {
    condition     = toset(keys(github_actions_secret.release_app)) == toset(["RELEASE_APP_ID", "RELEASE_APP_PRIVATE_KEY"])
    error_message = "a released repo must get both release App secrets"
  }

  assert {
    condition = alltrue([
      github_repository.this.allow_squash_merge,
      !github_repository.this.allow_merge_commit,
      !github_repository.this.allow_rebase_merge,
      github_repository.this.squash_merge_commit_title == "PR_TITLE",
      github_repository.this.squash_merge_commit_message == "BLANK",
      github_repository.this.delete_branch_on_merge,
      github_repository.this.allow_auto_merge,
      github_repository.this.allow_update_branch,
      github_repository.this.has_discussions,
    ])
    error_message = "a released repo must merge by squash only with PR title and blank message, and enable discussions"
  }

  assert {
    condition     = github_actions_repository_permissions.this.sha_pinning_required && github_workflow_repository_permissions.this.default_workflow_permissions == "read" && !github_workflow_repository_permissions.this.can_approve_pull_request_reviews
    error_message = "Actions must require SHA pinning, a read-only token and no PR approval"
  }

  assert {
    condition     = length(github_issue_label.this) == var.standard_labels_count && alltrue([for l in var.open_contribution_labels : !contains(keys(github_issue_label.this), l)])
    error_message = "a closed repo must get exactly the standard labels as individual github_issue_label resources"
  }
}

run "open_contributions" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier               = "released"
    open_contributions = true
    extra_labels       = { "area/docs" = { color = "0075ca", description = "Documentation" } }
  }

  assert {
    condition     = alltrue([for l in concat(var.open_contribution_labels, ["area/docs", "released"]) : contains(keys(github_issue_label.this), l)])
    error_message = "an open repo must get the contribution labels alongside the standard and its own labels"
  }
}

run "deployed_repo" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier        = "deployed"
    release_app = null
  }

  assert {
    condition     = keys(github_repository_ruleset.this) == ["default-branch"]
    error_message = "a deployed repo must get only the default-branch ruleset"
  }

  assert {
    condition     = [for c in github_repository_ruleset.this["default-branch"].rules[0].required_status_checks[0].required_check : c.context] == ["ci-gate"] && github_repository_ruleset.this["default-branch"].rules[0].required_linear_history
    error_message = "a deployed repo must get the full default-branch ruleset"
  }

  assert {
    condition     = length(github_actions_secret.release_app) == 0 && !github_repository.this.has_discussions
    error_message = "a deployed repo must get no release secrets and no discussions"
  }
}

run "config_repo" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier           = "config"
    required_check = null
    release_app    = null
  }

  assert {
    condition     = keys(github_repository_ruleset.this) == ["default-branch"]
    error_message = "a config repo must get no tag ruleset"
  }

  assert {
    condition     = length(github_actions_secret.release_app) == 0
    error_message = "a config repo must get no secrets"
  }

  assert {
    condition     = [for a in github_repository_ruleset.this["default-branch"].bypass_actors : "${a.actor_type}:${a.actor_id}:${a.bypass_mode}"] == ["RepositoryRole:5:always"]
    error_message = "the config default-branch ruleset must keep the admin bypass"
  }

  assert {
    condition = alltrue([
      github_repository_ruleset.this["default-branch"].rules[0].required_signatures,
      github_repository_ruleset.this["default-branch"].rules[0].non_fast_forward,
      github_repository_ruleset.this["default-branch"].rules[0].deletion,
      length(github_repository_ruleset.this["default-branch"].rules[0].pull_request) == 0,
      length(github_repository_ruleset.this["default-branch"].rules[0].required_status_checks) == 0,
    ])
    error_message = "a config repo must block deletion and force pushes and require signatures, without PR or check rules"
  }
}

run "extra_ruleset" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier = "released"
    extra_rulesets = {
      eval-baseline-gate = {
        include                = ["refs/heads/eval/**/*"]
        bypass_integration_ids = [456]
        required_checks        = ["eval-gate"]
      }
    }
  }

  assert {
    condition     = [for a in github_repository_ruleset.this["eval-baseline-gate"].bypass_actors : "${a.actor_type}:${a.actor_id}"] == ["RepositoryRole:5", "Integration:456"]
    error_message = "an extra ruleset must keep the admin bypass and add its declared integrations"
  }

  assert {
    condition     = [for c in github_repository_ruleset.this["eval-baseline-gate"].rules[0].required_status_checks[0].required_check : c.context] == ["eval-gate"]
    error_message = "an extra ruleset must carry its declared checks"
  }
}

run "rejects_unknown_tier" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier = "experimental"
  }

  expect_failures = [var.tier]
}

run "released_requires_release_app" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier        = "released"
    release_app = null
  }

  expect_failures = [var.release_app]
}

run "full_tiers_require_check" {
  command = plan

  module {
    source = "./modules/standard"
  }

  variables {
    tier           = "deployed"
    required_check = null
    release_app    = null
  }

  expect_failures = [var.required_check]
}

run "root_declares_dotgithub" {
  command = plan

  assert {
    condition     = module.dotgithub.repository == ".github"
    error_message = "the root configuration must manage the .github repo"
  }
}
