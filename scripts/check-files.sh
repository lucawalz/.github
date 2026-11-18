#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ISSUE_FORM_SCHEMA="vendor.github-issue-forms"
readonly VERBATIM_EXEMPT="CODE_OF_CONDUCT.md"
readonly REQUIRED_FILES=(
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  SECURITY.md
  SUPPORT.md
  README.md
  LICENSE
  justfile
  .github/PULL_REQUEST_TEMPLATE.md
  .github/ISSUE_TEMPLATE/bug.yml
  .github/ISSUE_TEMPLATE/feature.yml
  .github/ISSUE_TEMPLATE/config.yml
  .github/VULNERABILITY_REPORT.yml
)
readonly FORMS=(
  .github/ISSUE_TEMPLATE/bug.yml
  .github/ISSUE_TEMPLATE/feature.yml
  .github/VULNERABILITY_REPORT.yml
)

cd "$ROOT"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

if command -v check-jsonschema >/dev/null; then
  jsonschema=(check-jsonschema)
else
  jsonschema=(nix run nixpkgs#check-jsonschema --)
fi

for file in "${REQUIRED_FILES[@]}"; do
  [[ -f "$file" ]] || fail "missing $file"
done

for form in "${FORMS[@]}"; do
  [[ -f "$form" ]] || continue
  "${jsonschema[@]}" --builtin-schema "$ISSUE_FORM_SCHEMA" "$form" || fail "schema $form"
done

while IFS= read -r -d '' doc; do
  if grep -inE 'trailer|co-authored-by' "$doc"; then
    fail "$doc contains a disallowed term"
  fi
  [[ "$doc" == "$VERBATIM_EXEMPT" ]] && continue
  if LC_ALL=C grep -nE '[^[:print:][:space:]]' "$doc"; then
    fail "$doc contains non-ASCII characters"
  fi
  if grep -inwE 'you|your' "$doc"; then
    fail "$doc uses second person"
  fi
done < <(git ls-files -z '*.md')

if ((failures > 0)); then
  echo "check-files: $failures failure(s)" >&2
  exit 1
fi
echo "check-files: all checks passed"
