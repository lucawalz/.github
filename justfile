check:
    actionlint
    if command -v zizmor >/dev/null; then zizmor --min-severity medium .github/workflows; else nix run nixpkgs#zizmor -- --min-severity medium .github/workflows; fi
    scripts/check-files.sh
