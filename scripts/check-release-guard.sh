#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORKFLOW=".github/workflows/release.yml"
readonly TOKEN_ACTION="actions/create-github-app-token@"
readonly MESSAGE="release App secrets missing"

cd "$ROOT"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

if command -v yq >/dev/null; then
  yq=(yq)
else
  yq=(nix run nixpkgs#yq-go --)
fi

if [[ ! -f "$WORKFLOW" ]]; then
  echo "FAIL: missing $WORKFLOW" >&2
  exit 1
fi

mapfile -t jobs < <("${yq[@]}" '.jobs | to_entries | .[] | select(.value.steps[].uses | test("^'"$TOKEN_ACTION"'")) | .key' "$WORKFLOW" | sort -u)
((${#jobs[@]} > 0)) || fail "no job mints an App token"

for job in "${jobs[@]}"; do
  token_index="$("${yq[@]}" ".jobs.\"$job\".steps | to_entries | map(select(.value.uses | test(\"^$TOKEN_ACTION\"))) | .[0].key" "$WORKFLOW")"
  guard_run="$("${yq[@]}" ".jobs.\"$job\".steps[0].run // \"\"" "$WORKFLOW")"
  id_ref="$("${yq[@]}" ".jobs.\"$job\".steps[0].env.APP_ID // \"\"" "$WORKFLOW")"
  key_ref="$("${yq[@]}" ".jobs.\"$job\".steps[0].env.APP_KEY // \"\"" "$WORKFLOW")"

  [[ "$guard_run" == *"$MESSAGE"* ]] || { fail "$job: first step is not the secrets guard"; continue; }
  ((token_index > 0)) || fail "$job: token step runs before the guard"
  [[ "$id_ref" == '${{ secrets.RELEASE_APP_ID }}' ]] || fail "$job: guard env APP_ID does not read RELEASE_APP_ID"
  [[ "$key_ref" == '${{ secrets.RELEASE_APP_PRIVATE_KEY }}' ]] || fail "$job: guard env APP_KEY does not read RELEASE_APP_PRIVATE_KEY"
  [[ "$guard_run" != *'${{'* ]] || fail "$job: guard interpolates expressions into run"
done

if ((failures > 0)); then
  echo "check-release-guard: $failures failure(s)" >&2
  exit 1
fi
echo "check-release-guard: ${#jobs[@]} job(s) guarded"
