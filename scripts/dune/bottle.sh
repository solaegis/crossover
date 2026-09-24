#!/usr/bin/env bash
# Full Dune Awakening bottle workflow for task dune

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=../../lib/log.sh
source "${REPO_ROOT}/lib/log.sh"
# shellcheck source=../../lib/crossover.sh
source "${REPO_ROOT}/lib/crossover.sh"
# shellcheck source=../../lib/dune_paths.sh
source "${REPO_ROOT}/lib/dune_paths.sh"
# shellcheck source=../../lib/dune_battleye.sh
source "${REPO_ROOT}/lib/dune_battleye.sh"
# shellcheck source=../../lib/dune_runtime.sh
source "${REPO_ROOT}/lib/dune_runtime.sh"
# shellcheck source=../../lib/dune_setup.sh
source "${REPO_ROOT}/lib/dune_setup.sh"

dune_ensure_bottle_env

needs_gui_steps() {
  ! crossover_bottle_exists || ! dune_steam_exe_path >/dev/null 2>&1
}

main() {
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  log_info "=== task dune (bottle: ${CROSSOVER_BOTTLE}) ==="

  if ! crossover_support_root >/dev/null 2>&1; then
    log_error "CrossOver is not installed (expected /Applications/CrossOver.app)"
    exit 1
  fi

  dune_setup_run "$@"

  if needs_gui_steps; then
    crossover_open_app || true
    if ! crossover_bottle_exists; then
      dune_setup_print_bottle_create_steps
      log_warn "Create the bottle in CrossOver, then re-run: task dune"
    else
      dune_setup_print_gui_steps
      log_warn "Install Steam/Dune in the bottle, then re-run: task dune"
    fi
    exit 2
  fi

  log_info "Running BattlEye fix..."
  if ! dune_battleye_fix; then
    log_warn "BattlEye fix reported issues — run: task dune:fix-battleye"
  fi

  export DUNE_STRICT_DOCTOR=1
  if dune_doctor; then
    log_info "$(dune_bottle_name) bottle is ready (Steam, BattlEye, paths verified)"
    exit 0
  fi

  log_warn "Doctor reported issues — run: task dune:doctor"
  exit 1
}

main "$@"
