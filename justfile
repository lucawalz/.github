zizmor_min_severity := "medium"

check:
    actionlint
    if command -v zizmor >/dev/null; then zizmor --min-severity {{zizmor_min_severity}} .github/workflows; else nix run nixpkgs#zizmor -- --min-severity {{zizmor_min_severity}} .github/workflows; fi
    scripts/check-files.sh
