#!/usr/bin/env bash
set -euo pipefail

readonly OWNER=lucawalz
readonly SHARED_REPO=.github
readonly STANDARD_LABELS=(dependencies security needs-triage needs-info blocked released held stop-updating breaking)
readonly OPEN_LABELS=("good first issue" "help wanted")
readonly SNAPSHOT_ROOT="${ONBOARD_SNAPSHOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.snapshots}"

usage() {
  echo "usage: onboard.sh <repo> <released|deployed|config>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
repo="$1"
tier="$2"
[[ "$repo" =~ ^[A-Za-z0-9._-]+$ ]] || usage

case "$tier" in
  released)
    workflows=(pr-title zizmor codeql scorecard dependabot-automerge release)
    rulesets=(default-branch release-tags-creation release-tags-immutable)
    ;;
  deployed)
    workflows=(pr-title zizmor codeql scorecard)
    rulesets=(default-branch)
    ;;
  config)
    workflows=(pr-title zizmor dependabot-automerge)
    rulesets=(default-branch)
    ;;
  *) usage ;;
esac

module="${repo//./}"
[[ "$repo" != .* ]] || module="dot$module"

api() { gh api "$@"; }

err="$(mktemp)"
trap 'rm -f "$err"' EXIT
exists=1
if ! repo_json="$(api "repos/$OWNER/$repo" 2>"$err")"; then
  grep -q 'Not Found\|404' "$err" || { cat "$err" >&2; exit 1; }
  exists=0
fi

echo "== Snapshot =="
if ((exists)); then
  dir="$SNAPSHOT_ROOT/$repo"
  mkdir -p "$dir"
  rulesets_json="$(api "repos/$OWNER/$repo/rulesets")"
  labels_json="$(api "repos/$OWNER/$repo/labels" --paginate | jq -s 'add // []')"
  branch="$(jq -r .default_branch <<< "$repo_json")"
  if ! protection_json="$(api "repos/$OWNER/$repo/branches/$branch/protection" 2>"$err")"; then
    grep -q 'Branch not protected\|Branch not found' "$err" || { cat "$err" >&2; exit 1; }
    protection_json='{}'
  fi
  printf '%s\n' "$repo_json" > "$dir/repo.json"
  printf '%s\n' "$rulesets_json" > "$dir/rulesets.json"
  printf '%s\n' "$labels_json" > "$dir/labels.json"
  printf '%s\n' "$protection_json" > "$dir/branch-protection.json"
  echo "written to $dir: repo.json rulesets.json labels.json branch-protection.json"
  echo "secret names and workflow files are not exported: list them with gh secret list and git ls-files .github"
else
  echo "new repository: $OWNER/$repo does not exist yet, nothing to snapshot"
  echo "create it: gh repo create $OWNER/$repo --public"
fi

echo
echo "== Caller pins =="
tag="$(api "repos/$OWNER/$SHARED_REPO/releases/latest" | jq -r .tag_name)"
sha="$(api "repos/$OWNER/$SHARED_REPO/commits/$tag" | jq -r .sha)"
[[ -n "$tag" && "$tag" != null && "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "could not resolve the latest release of $OWNER/$SHARED_REPO" >&2; exit 1; }
for name in "${workflows[@]}"; do
  note=
  [[ "$name" != release ]] || note=" # after apply (Installation step 9)"
  echo "uses: $OWNER/.github/.github/workflows/$name.yml@$sha # $tag$note"
done

echo
echo "== Import blocks =="
import_block() {
  printf 'import {\n  to = %s\n  id = "%s"\n}\n\n' "$1" "$2"
}
import_block "module.$module.github_repository.this" "$repo"
if ((exists)); then
  while IFS=$'\t' read -r id name; do
    if printf '%s\n' "${rulesets[@]}" | grep -qxF -- "$name"; then
      import_block "module.$module.github_repository_ruleset.this[\"$name\"]" "$repo:$id"
    else
      echo "# ruleset '$name' is not declared for the $tier tier: add it to extra_rulesets to manage it"
    fi
  done < <(jq -r '.[] | [.id, .name] | @tsv' <<< "$rulesets_json")
  while IFS= read -r label; do
    if printf '%s\n' "${STANDARD_LABELS[@]}" | grep -qxF -- "$label"; then
      import_block "module.$module.github_issue_label.this[\"$label\"]" "$repo:$label"
    elif printf '%s\n' "${OPEN_LABELS[@]}" | grep -qxF -- "$label"; then
      echo "# label '$label' is an open contribution label: set open_contributions = true to manage it"
    else
      echo "# label '$label' is not standard: add it to extra_labels to manage it"
    fi
  done < <(jq -r '.[].name' <<< "$labels_json")
fi

if ((exists)) && printf '%s\n' "${workflows[@]}" | grep -qxF codeql; then
  echo
  echo "== Before pushing callers =="
  echo "gh api -X PATCH repos/$OWNER/$repo/code-scanning/default-setup -f state=not-configured   # only if CodeQL default setup is on, before the first codeql.yml run"
fi

if [[ $tier == released ]]; then
  echo
  echo "== Before apply =="
  echo "release App installed: https://github.com/settings/installations, Configure, add $repo (the release tag ruleset names the App as a bypass actor)"
fi

echo
echo "== After apply =="
echo "gh api -X PUT repos/$OWNER/$repo/private-vulnerability-reporting"
case "$tier" in
  released)
    echo "gh api -X PUT repos/$OWNER/$repo/immutable-releases   # after the first successful release"
    ;;
  deployed | config)
    echo "gh api -X PATCH repos/$OWNER/$repo -f pull_request_creation_policy=collaborators_only"
    ;;
esac
if ((exists)); then
  if [[ "$(jq 'length' <<< "$protection_json")" -gt 0 ]]; then
    echo "gh api -X DELETE repos/$OWNER/$repo/branches/$branch/protection   # classic branch protection exists"
  fi
fi
