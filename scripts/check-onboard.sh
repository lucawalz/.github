#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_SHA="0123456789abcdef0123456789abcdef01234567"
readonly TEST_TAG="v0.2.0"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

cat > "$work/bin/gh" <<FAKE
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\$arg" in
    -X | --method | -f | --input) echo "forbidden gh flag: \$arg" >&2; echo "\$*" >> "\$FAKE_GH_VIOLATIONS"; exit 1 ;;
  esac
done
case "\$*" in
  "api repos/lucawalz/newrepo") echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  "api repos/lucawalz/.github/releases/latest") echo '{"tag_name":"$TEST_TAG"}' ;;
  "api repos/lucawalz/.github/commits/$TEST_TAG") echo '{"sha":"$TEST_SHA"}' ;;
  "api repos/lucawalz/oldrepo") echo '{"name":"oldrepo","default_branch":"main"}' ;;
  "api repos/lucawalz/oldrepo/rulesets") echo '[{"id":1,"name":"default-branch"},{"id":2,"name":"release-tags-creation"},{"id":3,"name":"mystery"}]' ;;
  "api repos/lucawalz/oldrepo/labels --paginate") echo '[{"name":"dependencies"},{"name":"custom thing"},{"name":"good first issue"},{"name":"help wanted"}]' ;;
  "api repos/lucawalz/cfgrepo") echo '{"name":"cfgrepo","default_branch":"main"}' ;;
  "api repos/lucawalz/cfgrepo/rulesets") echo '[{"id":7,"name":"default-branch"},{"id":8,"name":"release-tags-creation"}]' ;;
  "api repos/lucawalz/cfgrepo/labels --paginate") echo '[]' ;;
  "api repos/lucawalz/cfgrepo/branches/main/protection") echo "gh: Branch not found (HTTP 404)" >&2; exit 1 ;;
  "api repos/lucawalz/oldrepo/branches/main/protection") echo '{"message":"Branch not protected","status":"404"}'; echo "gh: Branch not protected (HTTP 404)" >&2; exit 1 ;;
  "api repos/lucawalz/forbidden/branches/main/protection") echo '{"message":"Forbidden","status":"403"}'; echo "gh: Forbidden (HTTP 403)" >&2; exit 1 ;;
  "api repos/lucawalz/forbidden") echo '{"name":"forbidden","default_branch":"main"}' ;;
  "api repos/lucawalz/forbidden/rulesets") echo '[]' ;;
  "api repos/lucawalz/forbidden/labels --paginate") echo '[]' ;;
  *) echo "unexpected gh \$*" >&2; exit 1 ;;
esac
FAKE
chmod +x "$work/bin/gh"

export PATH="$work/bin:$PATH"
export ONBOARD_SNAPSHOT_DIR="$work/snapshots"
export FAKE_GH_VIOLATIONS="$work/violations"
cd "$ROOT"

has() {
  grep -qF -- "$2" <<< "$1" || fail "output lacks: $2"
}

out="$(scripts/onboard.sh oldrepo released 2>"$work/err")" || fail "existing repo run failed: $(cat "$work/err")"
for name in repo rulesets labels branch-protection; do
  [[ -s "$work/snapshots/oldrepo/$name.json" ]] || fail "snapshot lacks $name.json"
done
for workflow in pr-title zizmor codeql scorecard dependabot-automerge release; do
  has "$out" "uses: lucawalz/.github/.github/workflows/$workflow.yml@$TEST_SHA # $TEST_TAG"
done
has "$out" 'to = module.oldrepo.github_repository_ruleset.this["default-branch"]'
has "$out" 'id = "oldrepo:1"'
has "$out" 'to = module.oldrepo.github_issue_label.this["dependencies"]'
has "$out" 'id = "oldrepo:dependencies"'
has "$out" "to = module.oldrepo.github_repository.this"
has "$out" "custom thing"
has "$out" "== After apply =="
has "$out" "gh api -X PUT repos/lucawalz/oldrepo/private-vulnerability-reporting"
has "$out" "gh api -X PUT repos/lucawalz/oldrepo/immutable-releases"
has "$out" "release App installed"
has "$out" "# after apply (Installation step 9)"
has "$out" "== Before pushing callers =="
has "$out" "code-scanning/default-setup"
after="${out#*== After apply ==}"
grep -qF 'default-setup' <<< "$after" && fail "CodeQL default setup still under After apply"
has "$out" "== Before apply =="
before_apply="${out%%== After apply ==*}"
grep -qF 'settings/installations' <<< "${before_apply#*== Before apply ==}" || fail "release App install not under Before apply"
grep -qF 'settings/installations' <<< "$after" && fail "release App install still under After apply"
grep -q 'branches/main/protection' <<< "$out" && fail "classic protection step shown without protection"
has "$out" 'to = module.oldrepo.github_repository_ruleset.this["release-tags-creation"]'
grep -qF 'ruleset.this["mystery"]' <<< "$out" && fail "undeclared ruleset imported"
has "$out" "# ruleset 'mystery'"
grep -qF 'issue_label.this["good first issue"]' <<< "$out" && fail "open contribution label imported"
grep -qF 'issue_label.this["help wanted"]' <<< "$out" && fail "open contribution label imported"
has "$out" "# label 'good first issue'"
has "$out" "open_contributions = true"

out="$(scripts/onboard.sh cfgrepo config 2>"$work/err")" || fail "config repo run failed: $(cat "$work/err")"
has "$out" 'to = module.cfgrepo.github_repository_ruleset.this["default-branch"]'
grep -qF 'default-setup' <<< "$out" && fail "config tier prints CodeQL default setup"
grep -qF 'Before pushing callers' <<< "$out" && fail "config tier prints Before pushing callers"
grep -qF 'Before apply' <<< "$out" && fail "config tier prints Before apply"
grep -qF 'ruleset.this["release-tags-creation"]' <<< "$out" && fail "config tier imported a release ruleset"
has "$out" "# ruleset 'release-tags-creation'"
has "$out" "extra_rulesets"

out="$(scripts/onboard.sh newrepo config 2>"$work/err")" || fail "new repo run failed: $(cat "$work/err")"
has "$out" "new repository"
has "$out" "gh repo create lucawalz/newrepo --public"
has "$out" "to = module.newrepo.github_repository.this"
[[ ! -e "$work/snapshots/newrepo" ]] || fail "new repo wrote a snapshot"
grep -q 'github_repository_ruleset\|github_issue_label' <<< "$out" && fail "new repo printed ruleset or label imports"
has "$out" "pull_request_creation_policy=collaborators_only"
grep -q 'immutable-releases' <<< "$out" && fail "config tier lists immutable releases"

scripts/onboard.sh oldrepo bogus >/dev/null 2>&1 && fail "invalid tier accepted"
scripts/onboard.sh oldrepo bogus >/dev/null 2>&1 || [[ $? -eq 2 ]] || fail "invalid tier did not exit 2"
scripts/onboard.sh >/dev/null 2>&1 && fail "missing arguments accepted"
for bad in "a/b" "a b" '$(id)' "../x"; do
  scripts/onboard.sh "$bad" released >/dev/null 2>&1 && fail "invalid repo accepted: $bad"
done
scripts/onboard.sh "a/b" released >/dev/null 2>&1 || [[ $? -eq 2 ]] || fail "invalid repo did not exit 2"

just onboard "\$(touch $work/injected)" released >/dev/null 2>&1 && fail "command substitution repo accepted"
[[ ! -e "$work/injected" ]] || fail "repo ran as code"
just onboard oldrepo "\$(touch $work/injected)" >/dev/null 2>&1 && fail "command substitution tier accepted"
[[ ! -e "$work/injected" ]] || fail "tier ran as code"

scripts/onboard.sh forbidden released >/dev/null 2>"$work/err" && fail "403 on branch protection accepted"
grep -q 'Forbidden' "$work/err" || fail "403 error not surfaced"
[[ "$(jq length "$work/snapshots/oldrepo/branch-protection.json")" -eq 0 ]] || fail "unprotected snapshot is not an empty object"

[[ ! -s "$FAKE_GH_VIOLATIONS" ]] || fail "gh called with a write flag: $(cat "$FAKE_GH_VIOLATIONS")"

if ((failures > 0)); then
  echo "check-onboard: $failures failure(s)" >&2
  exit 1
fi
echo "check-onboard: all checks passed"
