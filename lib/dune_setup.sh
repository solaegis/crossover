# shellcheck shell=bash
# Dune: Awakening bottle setup — AVX env, GUI guidance, workflow orchestration.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "dune_setup.sh is a library; source it instead of executing." >&2
  exit 1
fi

dune_setup_print_steam_bottle_edit_lines() {
  local bottle
  bottle="$(dune_bottle_name)"
  log_colors
  log_dim "     CrossOver defaults to bottle name 'Steam' — change it to:"
  printf '%b     %b%s%b\n' \
    "${LOG_C_DIM}" "${LOG_C_BOLD_GREEN}" "$bottle" "${LOG_C_RESET}" >&2
}

dune_setup_print_bottle_create_steps() {
  log_heading "Create the Steam bottle in CrossOver (GUI):"
  echo >&2
  log_step 1 "CrossOver → Install a Windows Application → choose Steam."
  log_step 2 "Edit the default bottle name to: $(dune_bottle_name)"
  log_step 3 "Click Install and wait for the bottle to finish creating."
  echo >&2
}

dune_setup_print_gui_steps() {
  local bottle
  bottle="$(dune_bottle_name)"
  log_heading "Manual CrossOver steps (GUI — not fully automatable via CLI):"
  echo >&2
  log_step 1 "Launch Steam, sign in, install Dune: Awakening (AppID ${DUNE_STEAM_APPID})."
  log_step 2 "Run the game once from Steam to finish first-time setup."
  log_colors
  printf '%b  3.%b Bottle %b%s%b → Settings → %bGraphics: D3DMetal%b, %bSync: MSync%b.\n' \
    "${LOG_C_BOLD}" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_GREEN}" "$bottle" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_CYAN}" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_CYAN}" "${LOG_C_RESET}" >&2
  printf '%b  4.%b If on Apple Silicon, enable %bAdvertise AVX capabilities%b (or run task dune:configure).\n' \
    "${LOG_C_BOLD}" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_CYAN}" "${LOG_C_RESET}" >&2
  printf '%b  5.%b After install: %btask dune:fix-battleye%b then %btask dune:launch:game%b.\n' \
    "${LOG_C_BOLD}" "${LOG_C_RESET}" \
    "${LOG_C_CYAN}" "${LOG_C_RESET}" \
    "${LOG_C_CYAN}" "${LOG_C_RESET}" >&2
  echo >&2
}

dune_cxbottle_set_env_var() {
  local key="$1"
  local value="$2"
  local conf tmp
  if ! conf="$(dune_cxbottle_conf 2>/dev/null)" || [[ ! -f "$conf" ]]; then
    log_error "cxbottle.conf not found for bottle $(dune_bottle_name)"
    return 1
  fi
  if grep -Fq "\"${key}\"" "$conf"; then
    tmp="$(mktemp)"
    # shellcheck disable=SC2016
    sed "s/\"${key}\" = \".*\"/\"${key}\" = \"${value}\"/" "$conf" >"$tmp"
    mv "$tmp" "$conf"
    log_info "Updated ${key}=${value} in cxbottle.conf"
    return 0
  fi
  if grep -Fq '[EnvironmentVariables]' "$conf"; then
    tmp="$(mktemp)"
    awk -v key="$key" -v val="$value" '
      { print }
      /^\[EnvironmentVariables\]/ { print "\"" key "\" = \"" val "\""; done=1; next }
    ' "$conf" >"$tmp"
    mv "$tmp" "$conf"
    log_info "Added ${key}=${value} to cxbottle.conf"
    return 0
  fi
  log_error "No [EnvironmentVariables] section in cxbottle.conf"
  return 1
}

dune_setup_apply_bottle_env() {
  dune_cxbottle_set_env_var "WINEMSYNC" "1" || true
  if dune_host_is_apple_silicon; then
    dune_cxbottle_set_env_var "ROSETTA_ADVERTISE_AVX" "1"
  fi
}

dune_setup_wait_for_bottle_gui() {
  if crossover_bottle_exists; then
    return 0
  fi

  if [[ "${DUNE_SKIP_GUI_WAIT:-}" == 1 ]]; then
    log_warn "Bottle '$(dune_bottle_name)' not found (DUNE_SKIP_GUI_WAIT=1; skipping interactive wait)"
    dune_setup_print_bottle_create_steps
    return 0
  fi

  if [[ ! -t 2 ]]; then
    log_warn "Not a terminal; skipping interactive bottle wait"
    dune_setup_print_bottle_create_steps
    return 0
  fi

  dune_setup_print_bottle_create_steps
  crossover_open_app || true

  while true; do
    echo >&2
    if ! log_prompt_yn_default_y "Bottle \"$(dune_bottle_name)\" ready in CrossOver?"; then
      log_info "Finish creating the bottle in CrossOver, then answer Y when ready."
      continue
    fi
    if crossover_bottle_exists; then
      log_info "Bottle detected: $(crossover_bottle_root_dir)"
      return 0
    fi
    log_warn "Bottle '$(dune_bottle_name)' not found under $(crossover_bottles_root)/$(dune_bottle_name)"
  done
}

dune_setup_run() {
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-gui-wait)
        DUNE_SKIP_GUI_WAIT=1
        shift
        ;;
      *)
        log_error "unknown setup option: $1"
        return 2
        ;;
    esac
  done

  dune_ensure_bottle_env

  log_info "=== crossover dune setup (bottle: ${CROSSOVER_BOTTLE}) ==="

  if ! crossover_support_root >/dev/null 2>&1; then
    log_error "CrossOver not installed (expected under /Applications/CrossOver.app)"
    return 1
  fi
  log_info "CrossOver found: $(crossover_support_root)"

  if ! crossover_bottle_exists; then
    dune_setup_wait_for_bottle_gui || return 1
  fi

  if crossover_bottle_exists; then
    log_info "Bottle exists: $(crossover_bottle_root_dir)"
    dune_setup_apply_bottle_env
  else
    log_warn "Bottle '$(dune_bottle_name)' not found yet — complete GUI steps below"
    dune_setup_print_bottle_create_steps
  fi

  if dune_steam_exe_path >/dev/null 2>&1; then
    log_info "Steam executable detected in bottle"
  else
    log_warn "Steam not detected in bottle — install via CrossOver GUI"
    dune_setup_print_gui_steps
  fi

  if dune_launcher_exe >/dev/null 2>&1 && [[ -f "$(dune_launcher_exe)" ]]; then
    log_info "Dune: Awakening installed"
  else
    log_warn "Dune: Awakening not detected — install via Steam"
    dune_setup_print_gui_steps
  fi

  log_info "=== setup finished; running doctor ==="
  DUNE_STRICT_DOCTOR=1 dune_doctor || true
}
