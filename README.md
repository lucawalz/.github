# lucawalz/.github

Default community health files and the shared repository standard for the public repositories of `lucawalz`. GitHub applies the files here to every repository that does not provide its own.

## Tiers

Each repository belongs to one tier, which sets what it inherits and what it carries itself.

| Element | Released software (vigil, horizon, .github) | Continuously deployed (bedrock, blog) | Public config/profile (dotfiles, lucawalz) | Private |
|---|---|---|---|---|
| Community files | inherited plus own SECURITY, LICENSE | inherited plus own SECURITY, LICENSE | inherited, own LICENSE | inherited |
| Default-branch ruleset | full | full | deletion and force-push block, signed commits | per repository |
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

## Checks

```
just check
```

## License

[MIT](LICENSE)
