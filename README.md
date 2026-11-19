# .github

[![ci](https://github.com/lucawalz/.github/actions/workflows/ci.yml/badge.svg)](https://github.com/lucawalz/.github/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/lucawalz/.github)](https://github.com/lucawalz/.github/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Default community health files and the shared repository standard for the public repositories of lucawalz.

## Description

GitHub applies the community health files here ([CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [SECURITY.md](SECURITY.md), [SUPPORT.md](SUPPORT.md), the issue forms and the pull request template) to every repository of the account that does not provide its own. Issue templates are inherited all or nothing: a repository with any local template loses every default form.

The repository also holds the shared standard itself:

- [.github/workflows/](.github/workflows): reusable workflows that each repository calls from thin caller workflows.
- [renovate/default.json](renovate/default.json): the shared Renovate preset.
- [tofu/](tofu): OpenTofu configuration that declares the settings, rulesets, labels and release App secrets of every public repository.

### Tiers

Each repository belongs to one tier, which sets what it inherits and what it carries itself.

| Element | Released software ([vigil](https://github.com/lucawalz/vigil), [horizon](https://github.com/lucawalz/horizon), .github) | Continuously deployed ([bedrock](https://github.com/lucawalz/bedrock), [blog](https://github.com/lucawalz/blog)) | Public config/profile ([dotfiles](https://github.com/lucawalz/dotfiles), [lucawalz](https://github.com/lucawalz/lucawalz)) | Private |
|---|---|---|---|---|
| Community files | inherited plus own SECURITY, LICENSE | inherited plus own SECURITY, LICENSE | inherited, own LICENSE | inherited |
| Default-branch ruleset | full | full | deletion and force-push block, signed commits; PR and required check where CI runs | per repository |
| Tag ruleset and immutable releases | yes | no | no | no |
| Dependency updates | Dependabot plus shared auto-merge | Renovate with shared preset | Dependabot | per repository |
| Releases | release-please shared workflow, GoReleaser where binaries ship, attestations | none, the SHA is the version | none | none |
| Scanning | zizmor, CodeQL, secret scanning, Scorecard | zizmor, CodeQL where code exists, secret scanning, Scorecard | zizmor, secret scanning | per repository |
| Outside PRs | open | collaborators only | collaborators only | n/a |

A full default-branch ruleset blocks deletion and force pushes and requires linear history, signed commits, a squash-merged pull request with zero approvals, and one aggregate status check. The admin role is a bypass actor. Private repositories are not managed by `tofu/`; they inherit the community files and keep their own settings.

## Installation

A public repository adopts the standard in this order.

1. **Snapshot.** Export the repository's current settings, rulesets, classic branch protection, labels, secret names and workflow files to a file outside version control, so anything can be compared or restored.
2. **Choose a tier:** `released`, `deployed` or `config`, as in the table above.
3. **Remove duplicates.** Delete local CONTRIBUTING, CODE_OF_CONDUCT, SUPPORT and issue or PR templates that only duplicate the shared ones, and copied workflows that a shared workflow replaces. Keep LICENSE, and SECURITY.md in released and deployed repositories (Scorecard cannot see inherited files).
4. **Add callers** of the reusable workflows (see [Usage](#usage)), pinned to the full commit SHA of a release tag with the tag as a version comment. Add one aggregate job, by convention `ci-gate`, that needs every other CI job and fails if any of them failed. For dependency updates, add `renovate.json` extending the shared preset or a `dependabot.yml` with the auto-merge caller, as the tier requires.
5. **Wait for green.** Push the callers and wait until the aggregate check has passed on the default branch. The ruleset makes it required, so applying before it has ever passed blocks every pull request.
6. **Add the module call** to [tofu/repos.tf](tofu/repos.tf), with the tier, the aggregate check name and the repository's declared exceptions as inputs, and `import` blocks for everything that already exists (see [Import blocks](#import-blocks)).
7. **Plan and apply** with `just plan` and `just apply` (see [Running OpenTofu](#running-opentofu)). Review the plan before applying: no resource is destroyed, and imported rulesets update in place. A second `just plan` reports no changes.
8. **Delete classic branch protection** once the apply has activated the `default-branch` ruleset, with the command in the classic branch protection row of [Manual steps](#manual-steps).
9. **Released tier only: add the release caller** after the apply, because the apply creates the `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` secrets the release workflow reads. The release type and version files are set in the repository's `release-please-config.json`. After the first successful release, enable immutable releases.

   ```yaml
   name: release-please

   on:
     push:
       branches: [main]

   permissions:
     contents: read

   jobs:
     release:
       uses: lucawalz/.github/.github/workflows/release.yml@b4689c6655b628d5b755ad9a12ec7f247a72d392 # v0.2.0
       permissions:
         contents: read
         id-token: write
         attestations: write
       secrets:
         RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
         RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
   ```

### Import blocks

Creating an object that already exists on GitHub fails, so each adopted repository gets one `import` block per existing object. Ids:

| Object | Import id | Address |
|---|---|---|
| Repository | `<repo>` | `module.<repo>.github_repository.this` |
| Ruleset | `<repo>:<ruleset-id>` | `module.<repo>.github_repository_ruleset.this["<name>"]` |
| Label | `<repo>:<label>` | `module.<repo>.github_issue_label.this["<label>"]` |
| Release App secret | `<repo>:<SECRET_NAME>` | `module.<repo>.github_actions_secret.release_app["<SECRET_NAME>"]` |

List existing rulesets and labels with:

```
gh api repos/lucawalz/<repo>/rulesets -q '.[] | "\(.id) \(.name)"'
gh label list -R lucawalz/<repo>
```

Run the label listing right before planning. The labeler and Dependabot create labels on their own, and a standard label created between the listing and the apply makes the apply fail.

### Archived repositories

sentio-systems is archived; if unarchived, it is adopted like any new repository.

## Usage

### Reusable workflows

Callers reference a workflow by path and full commit SHA, with the release tag as a comment:

```yaml
jobs:
  codeql:
    uses: lucawalz/.github/.github/workflows/codeql.yml@<full-sha> # vX.Y.Z
    permissions:
      contents: read
      security-events: write
    with:
      languages: actions,go
```

Resolve a tag to its commit SHA with `gh api repos/lucawalz/.github/commits/vX.Y.Z -q .sha`. Dependabot or Renovate then keeps the pin current.

| Workflow | Purpose | Inputs |
|---|---|---|
| `codeql.yml` | CodeQL analysis | `languages` (required); `go-version-file`, which installs the declared Go version before analysis. A repository with a `go.work` passes `go-version-file: go.work`, because the extractor otherwise runs an older Go that rejects the workspace. |
| `zizmor.yml` | workflow security lint | none |
| `pr-title.yml` | Conventional Commits check on pull request titles | none |
| `scorecard.yml` | OpenSSF Scorecard | none |
| `dependabot-automerge.yml` | auto-merge of Dependabot updates | `update-types` (default `semver-minor,semver-patch`) |
| `labeler.yml` | path-based pull request labels from the caller's `.github/labeler.yml` | none |
| `needs-info.yml` | closes issues labelled `needs-info` after no reply from the author | `days` (default 30) |
| `release.yml` | release-please with the release App, optional GoReleaser and attestations | `goreleaser`, `attest-subject-path`; secrets `RELEASE_APP_ID`, `RELEASE_APP_PRIVATE_KEY` |

Each caller grants the permissions its called jobs need; the caller's top-level token stays read-only. The `needs-info` caller triggers on issue comments, so zizmor's `dangerous-triggers` rule is ignored for that one file in the repository's `.github/zizmor.yml`.

`release.yml` reads `release-please-config.json` and `.release-please-manifest.json` from the calling repository. Released repositories that attach assets set `"draft": true` and `"force-tag-creation": true` there, and GoReleaser sets `release.draft: true` and `release.use_existing_draft: true`. The workflow publishes the draft once assets and attestations are in place, so immutable releases never lock a half-built release. Anything that runs on publication triggers on `release: published`.

### Renovate preset

Repositories updated by Renovate extend the shared default preset in [renovate/default.json](renovate/default.json):

```json
{
  "extends": ["github>lucawalz/.github//renovate/default"]
}
```

### Running OpenTofu

[tofu/](tofu) uses the `integrations/github` provider. Each repository is one call of [tofu/modules/standard](tofu/modules/standard) in [tofu/repos.tf](tofu/repos.tf); its declared exceptions are inputs of that call:

| Input | Meaning |
|---|---|
| `name`, `tier` | repository name; `released`, `deployed` or `config` |
| `required_check` | the aggregate status check; required for released and deployed |
| `release_app` | release App id and key; required for released and only for it |
| `open_contributions` | adds `good first issue` and `help wanted` |
| `has_discussions` | Discussions outside the released tier |
| `extra_labels`, `extra_rulesets` | labels and rulesets beyond the standard |

Labels outside the standard and the declared extras are left alone.

The owner runs it from a workstation only; no CI job holds an admin token. `just plan` writes the encrypted plan to `tofu/tfplan` and `just apply` applies exactly that plan:

```
just plan
just apply
```

Both read these environment variables:

| Variable | Value |
|---|---|
| `GITHUB_TOKEN` | token with admin on the managed repositories |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | R2 token scoped to the `lucawalz-tofu-state` bucket |
| `AWS_ENDPOINT_URL_S3` | `https://<account-id>.r2.cloudflarestorage.com` |
| `TF_VAR_state_passphrase` | state and plan encryption passphrase, at least 16 characters |
| `TF_VAR_release_app_id`, `TF_VAR_release_app_private_key` | release App ID and private key |

Before each apply, `gh api user -q .plan.name` prints `pro`.

## Manual steps

The provider (v6.13.0) cannot manage these settings, so the owner sets them once per repository:

| Step | Applies to | Command |
|---|---|---|
| Private vulnerability reporting | every public repository | `gh api -X PUT repos/lucawalz/<repo>/private-vulnerability-reporting` |
| Immutable releases | released tier, after the first successful release | `gh api -X PUT repos/lucawalz/<repo>/immutable-releases` |
| Pull requests from collaborators only | deployed and config tiers | `gh api -X PATCH repos/lucawalz/<repo> -f pull_request_creation_policy=collaborators_only` |
| CodeQL default setup off | any repository that had it, right before the first `codeql.yml` caller run, since default setup rejects the caller's results | `gh api -X PATCH repos/lucawalz/<repo>/code-scanning/default-setup -f state=not-configured` |
| Classic branch protection removed | repositories that had it, after the apply | `gh api -X DELETE repos/lucawalz/<repo>/branches/main/protection` |
| Release App installed | released tier, before the first release run | GitHub settings, [Installed GitHub Apps](https://github.com/settings/installations), Configure, add the repository |
| Renovate App installed | Renovate repositories | same page, [Renovate](https://github.com/apps/renovate), Configure, add the repository |

The release App is created once with contents, pull requests and issues write. App installations are changed in the web interface.

## Support

See [SUPPORT.md](SUPPORT.md). Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Run the local checks before opening a pull request:

```
just check
```

## Authors and acknowledgment

Maintained by Luca Walz.

## License

[MIT](LICENSE)

## Project status

Maintained. Releases are listed in [CHANGELOG.md](CHANGELOG.md).
