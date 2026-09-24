# shellcheck shell=bash
# ESO bottle setup: Steam + Minion automation and GUI guidance.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "eso_setup.sh is a library; source it instead of executing." >&2
  exit 1
fi

_eso_setup_print_steam_crosstie_tail() {
  log_step 2 "Choose \"Steam\" on the install screen."
  eso_setup_print_steam_bottle_edit_lines
}

eso_setup_print_steam_bottle_edit_lines() {
  local bottle
  bottle="$(eso_bottle_name)"
  log_colors
  log_dim "     CrossOver defaults to:"
  log_dim "       CrossOver will install 'Steam' into a new Windows 10 bottle named 'Steam'"
  printf '%b     Click Edit%b on that line and change the bottle name to: %b%s%b\n' \
    "${LOG_C_BOLD_YELLOW}" "${LOG_C_RESET}" "${LOG_C_BOLD_GREEN}" "$bottle" "${LOG_C_RESET}" >&2
  log_dim "     (Windows 10 is fine; leave the installer source, language, and dependencies as-is.)"
}

eso_setup_print_bottle_create_steps() {
  log_heading "Create the Steam bottle in CrossOver (GUI):"
  echo >&2
  log_step 1 "CrossOver → Install a Windows Application."
  _eso_setup_print_steam_crosstie_tail
  log_step 3 "Click Install and wait for the bottle to finish creating."
  echo >&2
  log_colors
  printf '%bWhen the bottle appears in CrossOver, return here and answer %bY%b at the prompt.%b\n' \
    "${LOG_C_DIM}" "${LOG_C_BOLD_GREEN}" "${LOG_C_DIM}" "${LOG_C_RESET}" >&2
  echo >&2
}

eso_setup_print_gui_steps() {
  local bottle
  bottle="$(eso_bottle_name)"
  log_heading "Manual CrossOver steps (GUI — not fully automatable via CLI):"
  echo >&2
  log_step 1 "Open CrossOver → Install a Windows Application."
  _eso_setup_print_steam_crosstie_tail
  log_step 3 "Launch Steam, sign in, install The Elder Scrolls Online (AppID ${ESO_STEAM_APPID})."
  log_step 4 "Run ESO once from Steam to finish first-time setup."
  log_colors
  printf '%b  5.%b In CrossOver bottle settings for %b%s%b, prefer %bGraphics=DXMT%b and %bSync=MSync%b.\n' \
    "${LOG_C_BOLD}" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_GREEN}" "$bottle" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_CYAN}" "${LOG_C_RESET}" \
    "${LOG_C_BOLD_CYAN}" "${LOG_C_RESET}" >&2
  echo >&2
  log_colors
  log_dim "After Steam/ESO are installed, re-run:"
  printf '  %bcrossover eso doctor%b\n' "${LOG_C_CYAN}" "${LOG_C_RESET}" >&2
  printf '  %bcrossover eso launch steam%b\n' "${LOG_C_CYAN}" "${LOG_C_RESET}" >&2
  echo >&2
}

eso_setup_wait_for_bottle_gui() {
  if crossover_bottle_exists; then
    return 0
  fi

  if [[ "${ESO_SKIP_GUI_WAIT:-}" == 1 ]]; then
    log_warn "Bottle '${CROSSOVER_BOTTLE}' not found (ESO_SKIP_GUI_WAIT=1; skipping interactive wait)"
    eso_setup_print_bottle_create_steps
    return 0
  fi

  if [[ ! -t 2 ]]; then
    log_warn "Not a terminal; skipping interactive bottle wait"
    eso_setup_print_bottle_create_steps
    return 0
  fi

  eso_setup_print_bottle_create_steps
  crossover_open_app || true

  while true; do
    echo >&2
    if ! log_prompt_yn_default_y "Bottle \"$(eso_bottle_name)\" ready in CrossOver?"; then
      log_info "Finish creating the bottle in CrossOver, then answer Y when ready."
      continue
    fi
    if crossover_bottle_exists; then
      log_info "Bottle detected: $(crossover_bottle_root_dir)"
      return 0
    fi
    log_warn "Bottle '${CROSSOVER_BOTTLE}' not found under $(crossover_bottles_root)/$(eso_bottle_name)"
    log_info "Check the bottle name (Edit → ${CROSSOVER_BOTTLE}), then answer Y when ready."
  done
}

eso_setup_ensure_mac_addons() {
  local addons
  if ! addons="$(eso_mac_addons_dir 2>/dev/null)"; then
    addons="$(eso_default_mac_addons)"
  fi
  if [[ ! -d "$addons" ]]; then
    mkdir -p "$addons"
    log_info "Created Mac AddOns directory: $addons"
  else
    log_info "Mac AddOns directory ready: $addons"
  fi
}

eso_setup_check_minion_mac_app() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_warn "Minion setup skipped (native Minion.app is macOS-only)"
    return 0
  fi
  if ! eso_minion_mac_app_available; then
    log_warn "Minion.app not found at ${ESO_MINION_MAC_APP} — install Minion for Mac"
    return 1
  fi
  log_info "Minion.app ready: ${ESO_MINION_MAC_APP}"
  log_info "Point Minion at AddOns when prompted: $(eso_mac_addons_dir 2>/dev/null || eso_default_mac_addons)"
}

eso_setup_create_launchers() {
  local desktop_dir wine bottle steam_app
  desktop_dir="${ESO_LAUNCHER_DIR:-${HOME}/Desktop}"
  if [[ ! -d "$desktop_dir" ]]; then
    desktop_dir="${HOME}"
  fi
  if ! wine="$(crossover_wine_bin 2>/dev/null)"; then
    log_warn "CrossOver not found; skipping desktop launchers"
    return 0
  fi
  bottle="$(eso_bottle_name)"
  steam_app="$(eso_steam_cx_app)"

  cat >"${desktop_dir}/Launch_ESO_Steam.command" <<EOF
#!/bin/sh
exec "${wine}" --bottle "${bottle}" --cx-app "${steam_app}"
EOF
  chmod +x "${desktop_dir}/Launch_ESO_Steam.command"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    cat >"${desktop_dir}/Launch_Minion.command" <<EOF
#!/bin/sh
open -a "${ESO_MINION_MAC_APP}"
EOF
    chmod +x "${desktop_dir}/Launch_Minion.command"
    log_info "Desktop launchers: ${desktop_dir}/Launch_ESO_Steam.command, Launch_Minion.command"
  else
    log_info "Desktop launcher: ${desktop_dir}/Launch_ESO_Steam.command"
  fi
}

eso_setup_run() {
  local skip_launchers=false
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-launchers)
        skip_launchers=true
        shift
        ;;
      --skip-gui-wait)
        ESO_SKIP_GUI_WAIT=1
        shift
        ;;
      *)
        log_error "unknown setup option: $1"
        return 2
        ;;
    esac
  done

  eso_ensure_bottle_env

  log_info "=== crossover eso setup (bottle: ${CROSSOVER_BOTTLE}) ==="

  if ! crossover_support_root >/dev/null 2>&1; then
    log_error "CrossOver not installed (expected under /Applications/CrossOver.app)"
    return 1
  fi
  log_info "CrossOver found: $(crossover_support_root)"

  if ! crossover_bottle_exists; then
    if ! eso_setup_wait_for_bottle_gui; then
      return 1
    fi
  fi

  if crossover_bottle_exists; then
    log_info "Bottle exists: $(crossover_bottle_root_dir)"
  else
    log_warn "Bottle '${CROSSOVER_BOTTLE}' not found yet — complete GUI steps below"
    eso_setup_print_bottle_create_steps
  fi

  eso_setup_ensure_mac_addons
  eso_setup_check_minion_mac_app || log_warn "Minion.app check failed"

  if crossover_bottle_exists; then
    if [[ "$skip_launchers" == false ]]; then
      eso_setup_create_launchers
    fi
  else
    log_warn "Skipping launchers until bottle '${CROSSOVER_BOTTLE}' exists"
  fi

  if eso_steam_exe_path >/dev/null 2>&1; then
    log_info "Steam executable detected in bottle"
  else
    log_warn "Steam not detected in bottle — install via CrossOver GUI"
    eso_setup_print_gui_steps
  fi

  log_info "=== setup finished; running doctor ==="
  eso_doctor || true
}
