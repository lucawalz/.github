tofu := `command -v tofu >/dev/null && echo tofu || echo "nix run nixpkgs#opentofu --"`

check:
    actionlint
    if command -v zizmor >/dev/null; then zizmor --min-severity medium .; else nix run nixpkgs#zizmor -- --min-severity medium .; fi
    scripts/check-files.sh
    scripts/check-release-guard.sh
    scripts/check-renovate.sh
    {{tofu}} fmt -check -recursive tofu
    {{tofu}} -chdir=tofu init -backend=false -input=false
    {{tofu}} -chdir=tofu validate
    {{tofu}} -chdir=tofu test

plan:
    {{tofu}} -chdir=tofu init -input=false
    {{tofu}} -chdir=tofu plan

apply:
    {{tofu}} -chdir=tofu init -input=false
    {{tofu}} -chdir=tofu apply
