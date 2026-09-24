#!/usr/bin/env bash
# Install bats-core into .tools/bats when not already on PATH.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/.tools"
BATS_DIR="${TOOLS_DIR}/bats-core"
BATS_VERSION="${BATS_VERSION:-v1.11.1}"

if command -v bats >/dev/null 2>&1; then
  echo "bats already available: $(command -v bats)"
  bats --version
  exit 0
fi

mkdir -p "${TOOLS_DIR}"

if [[ ! -d "${BATS_DIR}/.git" ]]; then
  git clone --depth 1 --branch "${BATS_VERSION}" \
    https://github.com/bats-core/bats-core.git "${BATS_DIR}"
fi

"${BATS_DIR}/install.sh" "${TOOLS_DIR}/bats"

echo "Installed bats to ${TOOLS_DIR}/bats/bin/bats"
"${TOOLS_DIR}/bats/bin/bats" --version
