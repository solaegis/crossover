# shellcheck shell=bash
# Shared helpers for crossover. Source from bin/ or tests; do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "common.sh is a library; source it instead of executing." >&2
  exit 1
fi

crossover_repo_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s\n' "$here"
}

crossover_lib_dir() {
  local root
  root="$(crossover_repo_root)"
  printf '%s/lib\n' "$root"
}

crossover_ties_dir() {
  local root
  root="$(crossover_repo_root)"
  printf '%s/ties\n' "$root"
}

crossover_tie_path() {
  local name="${1:?tie name required}"
  local path
  name="${name%.tie}"
  path="$(crossover_ties_dir)/${name}.tie"
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  return 1
}
