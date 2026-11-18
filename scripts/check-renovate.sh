#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RENOVATE_VERSION="44.239.1"

cd "$ROOT"
npx --yes --package "renovate@${RENOVATE_VERSION}" -- renovate-config-validator --strict --no-global renovate/*.json
