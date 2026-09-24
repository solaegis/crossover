#!/usr/bin/env bash
# Exclude all CrossOver bottles from Time Machine backups.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../lib/log.sh
source "${REPO_ROOT}/lib/log.sh"
# shellcheck source=../lib/crossover.sh
source "${REPO_ROOT}/lib/crossover.sh"
# shellcheck source=../lib/timemachine.sh
source "${REPO_ROOT}/lib/timemachine.sh"

main() {
  local mode=exclude
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        mode=status
        shift
        ;;
      *)
        log_error "unknown option: $1"
        return 2
        ;;
    esac
  done

  local bottles_root
  bottles_root="$(crossover_bottles_root)"
  mkdir -p "$bottles_root"

  case "$mode" in
    exclude)
      crossover_timemachine_exclude "$bottles_root"
      ;;
    status)
      crossover_timemachine_print_status "$bottles_root"
      ;;
  esac
}

main "$@"
