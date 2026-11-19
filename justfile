tofu := `command -v tofu >/dev/null && echo tofu || echo "nix run nixpkgs#opentofu --"`

check:
    actionlint
    if command -v zizmor >/dev/null; then zizmor --min-severity medium .; else nix run nixpkgs#zizmor -- --min-severity medium .; fi
    scripts/check-files.sh
    scripts/check-release-guard.sh
    scripts/check-renovate.sh
    scripts/check-tofu-env.sh
    {{tofu}} fmt -check -recursive tofu
    {{tofu}} -chdir=tofu init -backend=false -input=false
    {{tofu}} -chdir=tofu validate
    {{tofu}} -chdir=tofu test

keychain_item := "tofu-state-passphrase"
app_key_path := "/Volumes/bedrock-keys/github/versionabot.pem"
app_slug := "versionabot"

r2-session:
    #!/usr/bin/env bash
    set -euo pipefail
    names=(AWS_ENDPOINT_URL_S3 AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY)
    flags=(-r -rs -rs)
    values=()
    for i in 0 1 2; do
      printf '%s: ' "${names[i]}" >&2
      read "${flags[i]}" value
      [[ "${flags[i]}" == -rs ]] && echo >&2
      [[ -n "$value" ]] || { echo "${names[i]} must not be empty" >&2; exit 1; }
      values+=("$value")
    done
    for i in 0 1 2; do
      printf 'export %s=%q\n' "${names[i]}" "${values[i]}"
    done

plan: (_tofu "plan")

apply: (_tofu "apply")

_tofu action:
    #!/usr/bin/env bash
    set -euo pipefail
    die() { echo "$*" >&2; exit 1; }
    for var in AWS_ENDPOINT_URL_S3 AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
      [[ -n "${!var:-}" ]] || die 'run: eval "$(just r2-session)"'
    done
    app_id="$(gh api apps/{{app_slug}} -q .id)"
    [[ "$app_id" =~ ^[0-9]+$ ]] || die "gh returned no numeric App ID for {{app_slug}}"
    plan_name="$(gh api user -q .plan.name)"
    [[ "$plan_name" == pro ]] || die "account plan is '$plan_name', not pro"
    [[ -r "{{app_key_path}}" ]] || die "cannot read {{app_key_path}}"
    TF_VAR_state_passphrase="$(security find-generic-password -a "$USER" -s {{keychain_item}} -w)"
    export TF_VAR_state_passphrase
    TF_VAR_release_app_id="$app_id"
    export TF_VAR_release_app_id
    TF_VAR_release_app_private_key="$(cat "{{app_key_path}}")"
    export TF_VAR_release_app_private_key
    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    {{tofu}} -chdir=tofu init -input=false
    if [[ "{{action}}" == plan ]]; then
      {{tofu}} -chdir=tofu plan -out=tfplan
    else
      {{tofu}} -chdir=tofu apply tfplan
    fi
