#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_ENDPOINT="https://example.invalid/it's here"
readonly TEST_ACCESS_KEY='access key"with$quotes'
readonly TEST_SECRET_KEY="secret 'key' \$HOME \`id\`"
readonly TEST_APP_ID="4242"
readonly TEST_PASSPHRASE="fake-passphrase-value"
readonly TEST_GH_TOKEN="fake-gh-token"
readonly TEST_PEM="fake pem content"
readonly R2_VARS=(AWS_ENDPOINT_URL_S3 AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY)

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
case "\$*" in
  "api apps/versionabot -q .id") echo "\${FAKE_APP_ID-$TEST_APP_ID}" ;;
  "api user -q .plan.name") echo "\${FAKE_PLAN:-pro}" ;;
  "auth token") [[ -z "\${FAKE_TOKEN_FAIL:-}" ]] || { echo "fake token failure" >&2; exit 1; }; echo "$TEST_GH_TOKEN" ;;
  *) echo "unexpected gh \$*" >&2; exit 1 ;;
esac
FAKE
cat > "$work/bin/security" <<FAKE
#!/usr/bin/env bash
[[ -z "\${FAKE_SECURITY_FAIL:-}" ]] || { echo "fake security failure" >&2; exit 1; }
[[ "\$*" == "find-generic-password -a \$USER -s tofu-state-passphrase -w" ]] || { echo "unexpected security \$*" >&2; exit 1; }
echo "$TEST_PASSPHRASE"
FAKE
cat > "$work/bin/tofu" <<'FAKE'
#!/usr/bin/env bash
{
  echo "tofu $*"
  echo "TF_VAR_state_passphrase=$TF_VAR_state_passphrase"
  echo "TF_VAR_release_app_id=$TF_VAR_release_app_id"
  echo "TF_VAR_release_app_private_key=$TF_VAR_release_app_private_key"
  echo "GITHUB_TOKEN=$GITHUB_TOKEN"
} >> "$FAKE_TOFU_LOG"
FAKE
chmod +x "$work/bin/"*
printf '%s' "$TEST_PEM" > "$work/key.pem"

cd "$ROOT"
export PATH="$work/bin:$PATH"
export FAKE_TOFU_LOG="$work/tofu.log"

session_out="$(printf '%s\n%s\n%s\n' "$TEST_ENDPOINT" "$TEST_ACCESS_KEY" "$TEST_SECRET_KEY" | just r2-session 2>"$work/session.err")" || fail "r2-session exited non-zero"
(
  eval "$session_out"
  [[ "$AWS_ENDPOINT_URL_S3" == "$TEST_ENDPOINT" ]] || exit 1
  [[ "$AWS_ACCESS_KEY_ID" == "$TEST_ACCESS_KEY" ]] || exit 1
  [[ "$AWS_SECRET_ACCESS_KEY" == "$TEST_SECRET_KEY" ]] || exit 1
) || fail "r2-session output does not eval to the entered values"
if [[ "$(grep -vc '^export ' <<< "$session_out")" -ne 0 ]]; then
  fail "r2-session printed something other than export lines"
fi

for empty in 1 2 3; do
  answers=("$TEST_ENDPOINT" "$TEST_ACCESS_KEY" "$TEST_SECRET_KEY")
  answers[empty-1]=""
  out="$(printf '%s\n' "${answers[@]}" | just r2-session 2>"$work/empty.err")" && fail "r2-session accepted empty answer $empty"
  [[ -z "$out" ]] || fail "r2-session printed to stdout on a refused run (answer $empty)"
  grep -q 'must not be empty' "$work/empty.err" || fail "r2-session refusal $empty lacks its message"
done

refuses() {
  local expected="$1" err
  shift
  err="$("$@" 2>&1 >/dev/null)" && { fail "ran despite: $expected"; return; }
  grep -qF -- "$expected" <<< "$err" || fail "stderr lacks '$expected', got: $err"
}

export AWS_ENDPOINT_URL_S3="$TEST_ENDPOINT" AWS_ACCESS_KEY_ID="$TEST_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$TEST_SECRET_KEY"

readonly HINT='run: eval "$(just r2-session)"'
for action in plan apply; do
  for var in "${R2_VARS[@]}"; do
    refuses "$HINT" env -u "$var" just --set app_key_path "$work/key.pem" "$action"
    refuses "$HINT" env "$var=" just --set app_key_path "$work/key.pem" "$action"
  done
  refuses "account plan is 'free', not pro" env FAKE_PLAN=free just --set app_key_path "$work/key.pem" "$action"
  refuses "cannot read $work/missing.pem" just --set app_key_path "$work/missing.pem" "$action"
  refuses "no numeric App ID" env FAKE_APP_ID= just --set app_key_path "$work/key.pem" "$action"
  refuses "no numeric App ID" env FAKE_APP_ID=abc just --set app_key_path "$work/key.pem" "$action"
  refuses "fake security failure" env FAKE_SECURITY_FAIL=1 just --set app_key_path "$work/key.pem" "$action"
  refuses "fake token failure" env FAKE_TOKEN_FAIL=1 just --set app_key_path "$work/key.pem" "$action"
  refuses "Is a directory" just --set app_key_path "$work" "$action"
done
[[ ! -s "$FAKE_TOFU_LOG" ]] || fail "tofu ran despite a failed check"

just --set app_key_path "$work/key.pem" plan >/dev/null 2>"$work/plan.err" || fail "plan failed on the success path"
for expected in \
  "tofu -chdir=tofu init -input=false" \
  "tofu -chdir=tofu plan -out=tfplan" \
  "TF_VAR_state_passphrase=$TEST_PASSPHRASE" \
  "TF_VAR_release_app_id=$TEST_APP_ID" \
  "TF_VAR_release_app_private_key=$TEST_PEM" \
  "GITHUB_TOKEN=$TEST_GH_TOKEN"; do
  grep -qxF "$expected" "$FAKE_TOFU_LOG" || fail "plan log lacks: $expected"
done

: > "$FAKE_TOFU_LOG"
just --set app_key_path "$work/key.pem" apply >/dev/null 2>&1 || fail "apply failed on the success path"
grep -qxF "tofu -chdir=tofu apply tfplan" "$FAKE_TOFU_LOG" || fail "apply did not run tofu apply tfplan"

if grep -rF -e "$TEST_ACCESS_KEY" -e "$TEST_SECRET_KEY" "$work/session.err" "$work/plan.err" >/dev/null; then
  fail "a secret leaked to stderr"
fi

if ((failures > 0)); then
  echo "check-tofu-env: $failures failure(s)" >&2
  exit 1
fi
echo "check-tofu-env: all checks passed"
