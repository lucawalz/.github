check:
    actionlint
    if command -v zizmor >/dev/null; then zizmor --min-severity medium .; else nix run nixpkgs#zizmor -- --min-severity medium .; fi
    scripts/check-files.sh
    scripts/check-release-guard.sh
    scripts/check-renovate.sh
