#!/usr/bin/env bash
# Full Elder Scrolls bottle workflow for task eso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=../../lib/log.sh
source "${REPO_ROOT}/lib/log.sh"
# shellcheck source=../../lib/crossover.sh
source "${REPO_ROOT}/lib/crossover.sh"
# shellcheck source=../../lib/eso_paths.sh
source "${REPO_ROOT}/lib/eso_paths.sh"
# shellcheck source=../../lib/eso_runtime.sh
source "${REPO_ROOT}/lib/eso_runtime.sh"
# shellcheck source=../../lib/eso_setup.sh
source "${REPO_ROOT}/lib/eso_setup.sh"

eso_ensure_bottle_env

needs_gui_steps() {
  ! crossover_bottle_exists || ! eso_steam_exe_path >/dev/null 2>&1
}

main() {
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  log_info "=== task eso (bottle: ${CROSSOVER_BOTTLE}) ==="

  if ! crossover_support_root >/dev/null 2>&1; then
    log_error "CrossOver is not installed (expected /Applications/CrossOver.app)"
    exit 1
  fi

  eso_setup_run "$@"

  if needs_gui_steps; then
    crossover_open_app || true
    if ! crossover_bottle_exists; then
      eso_setup_print_bottle_create_steps
      log_warn "Create the bottle in CrossOver, then re-run: task eso"
    else
      eso_setup_print_gui_steps
      log_warn "Install Steam/ESO in the bottle, then re-run: task eso"
    fi
    exit 2
  fi

  export ESO_STRICT_DOCTOR=1
  if eso_doctor; then
    log_info "$(eso_bottle_name) bottle is ready (Steam, Minion, AddOns paths verified)"
    exit 0
  fi

  log_warn "Doctor reported issues — run: task eso:doctor"
  exit 1
}

main "$@"
