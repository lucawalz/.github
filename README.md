# lucawalz/.github

Default community health files and the shared repository standard for the public repositories of `lucawalz`. GitHub applies the files here to every repository that does not provide its own.

## Tiers

Each repository belongs to one tier, which sets what it inherits and what it carries itself.

| Element | Released software (vigil, horizon, .github) | Continuously deployed (bedrock, blog) | Public config/profile (dotfiles, lucawalz) | Private |
|---|---|---|---|---|
| Community files | inherited plus own SECURITY, LICENSE | inherited plus own SECURITY, LICENSE | inherited, own LICENSE | inherited |
| Default-branch ruleset | full | full | deletion and force-push block, signed commits; PR and required check where CI runs | per repository |
| Tag ruleset and immutable releases | yes | no | no | no |
| Dependency updates | Dependabot plus shared auto-merge | Renovate with shared preset | Dependabot | per repository |
| Releases | release-please shared workflow, GoReleaser where binaries ship, attestations | none, the SHA is the version | none | none |
| Scanning | zizmor, CodeQL, secret scanning, Scorecard | zizmor, CodeQL where code exists, secret scanning, Scorecard | zizmor, secret scanning | per repository |
| Outside PRs | open | collaborators only | collaborators only | n/a |

## Renovate preset

Repositories updated by Renovate extend the shared default preset in `renovate/default.json`:

```json
{
  "extends": ["github>lucawalz/.github//renovate/default"]
}
```

## Repository settings

`tofu/` declares the settings, rulesets, labels and release App secrets of every public repository with OpenTofu and the `integrations/github` provider. Each repository is one call of `tofu/modules/standard` in `tofu/repos.tf`; its declared exceptions (extra labels, extra rulesets, the required check) are inputs of that call. Labels outside the standard and the declared extras are left alone.

Adopting a repository imports it before anything is managed: its module call in `tofu/repos.tf` comes with an `import` block for the repository (id `<repo>`) and one for every standard or declared label that already exists on it (id `<repo>:<label>`), plus existing rulesets (id `<repo>:<ruleset-id>`) and release App secrets (id `<repo>:<SECRET_NAME>`). Creating any of these where it already exists fails.

The owner runs it from the Mac only; `just plan` writes the encrypted plan to `tofu/tfplan` and `just apply` applies exactly that plan:

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

### Manual steps

The provider (v6.13.0) cannot manage these settings, so the owner sets them once per repository with `gh`:

- Private vulnerability reporting, every public repository: `gh api -X PUT repos/lucawalz/<repo>/private-vulnerability-reporting`
- Immutable releases, released tier: `gh api -X PUT repos/lucawalz/<repo>/immutable-releases`
- Pull requests from collaborators only, deployed and config tiers: `gh api -X PATCH repos/lucawalz/<repo> -f pull_request_creation_policy=collaborators_only`
- Classic branch protection, dotfiles only, once the apply has activated its `default-branch` ruleset: `gh api -X DELETE repos/lucawalz/dotfiles/branches/main/protection`
- Account plan, before each apply: `gh api user -q .plan.name` prints `pro`
- Release App: created once with contents, pull requests and issues write, installed on every released repository

## Checks

```
just check
```

## License

[MIT](LICENSE)
