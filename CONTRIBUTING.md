# Contributing

Contributions are welcome. This guide applies to every repository under `lucawalz` that does not ship its own CONTRIBUTING file.

## Before starting

- Open an issue first for anything larger than a small fix, so the approach can be agreed before work starts.
- Some repositories accept pull requests from collaborators only. Issues stay open everywhere.

## Development flow

1. Fork the repository and create a branch from the default branch.
2. Make the change, keeping each pull request focused on one topic.
3. Run the local checks with `just check` where the repository has a justfile, otherwise follow its README.
4. Open a pull request and fill in the template.
5. CI must pass and the maintainer must approve before the change is merged. Pull requests are squash-merged.

## Branches

Branch names follow [Conventional Branch](https://conventionalbranch.org/): `<type>/<description>`, for example `feat/add-dark-mode` or `fix/issue-42-broken-link`. Types are `feat`, `fix`, `hotfix`, `release` and `chore`. Descriptions use lowercase letters, numbers, hyphens and dots only.

## Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), with the same types as pull request titles below.

## Pull request titles

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), because the title becomes the squashed commit and feeds release notes:

```
<type>(<optional scope>): <description>
```

Common types are `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci` and `chore`. A breaking change adds `!` after the type or scope, for example `feat(api)!: remove the legacy endpoint`.

Commits on the default branch must be signed.

## Documentation

READMEs follow [Make a README](https://www.makeareadme.com/). The name, badges and a one-line description open the file, followed by its sections in this order: Description, Installation, Usage, Support, Roadmap, Contributing, Authors and acknowledgment, License, Project status. Sections that do not apply are left out, and repository-specific sections such as Architecture or Repository layout go after Usage.

Architecture decisions are recorded in `docs/adr/` in [Michael Nygard's format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), one file per decision, named `NNNN-imperative-title.md`:

```
# 7. Use one signing key

Date: 2026-11-20

## Status

Accepted

## Context

## Decision

## Consequences
```

Status is Proposed, Accepted, Deprecated or Superseded by a later record, which is linked. A record is short: the forces at play and the rejected alternatives in Context, the decision in a few sentences, and what follows from it in Consequences. Accepted records are not rewritten; a changed decision gets a new record that supersedes the old one. `docs/adr/README.md` lists every record with its status.

## AI-assisted contributions

AI-assisted work is welcome under these rules:

- The submitter answers for every line of the change, understands it, and can explain and defend it in review.
- AI use is disclosed in the pull request description, with a short note on what the tool did.
- Low-effort AI pull requests, such as unreviewed generated changes, drive-by rewrites or changes that fail the checks, are closed without detailed review.

## Governance

Each repository has a single maintainer, who reviews and merges changes and decides on direction. Decisions are made and recorded in issues and pull requests, so the reasoning stays public. Disagreements are raised there as well.

## Code of conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
