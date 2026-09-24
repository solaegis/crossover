# shellcheck shell=bash
# Dune: Awakening recipe — launch, paths display, doctor.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "dune_runtime.sh is a library; source it instead of executing." >&2
  exit 1
fi

# CrossOver strips ":" from bottle names; match the on-disk bottle.
DUNE_DEFAULT_BOTTLE_NAME="${DUNE_DEFAULT_BOTTLE_NAME:-Dune Awakening (Steam)}"
DUNE_STEAM_APPID="${DUNE_STEAM_APPID:-1172710}"

dune_bottle_name() {
  printf '%s\n' "${CROSSOVER_BOTTLE:-${DUNE_DEFAULT_BOTTLE_NAME}}"
}

dune_ensure_bottle_env() {
  export CROSSOVER_BOTTLE="${CROSSOVER_BOTTLE:-$(dune_bottle_name)}"
}

dune_host_is_apple_silicon() {
  [[ "$(uname -s)" == "Darwin" ]] || return 1
  case "$(uname -m)" in
    arm64) return 0 ;;
  esac
  return 1
}

dune_run() {
  local wine bottle cx_app
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  dune_ensure_bottle_env
  bottle="${CROSSOVER_BOTTLE}"
  cx_app="${1:?cx-app executable required}"
  shift
  "$wine" --bottle "$bottle" --cx-app "$cx_app" "$@"
}

dune_run_cmd() {
  local wine bottle
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  dune_ensure_bottle_env
  bottle="${CROSSOVER_BOTTLE}"
  "$wine" --bottle "$bottle" "$@"
}

dune_launch_steam() {
  dune_run "$(dune_steam_cx_app)"
}

dune_launch_game() {
  local wrapper
  if ! wrapper="$(dune_be_wrapper_exe 2>/dev/null)"; then
    log_error "DuneSandbox_BE.exe not found — install Dune: Awakening in the bottle first"
    return 1
  fi
  if [[ ! -f "$wrapper" ]]; then
    log_error "BattlEye wrapper missing: $wrapper"
    return 1
  fi
  log_info "Launching via BattlEye wrapper (DuneSandbox_BE.exe)"
  dune_run_cmd \
    --workdir 'C:\Program Files (x86)\Steam\steamapps\common\DuneAwakening\DuneSandbox\Binaries\Win64' \
    --cx-app "DuneSandbox_BE.exe"
}

dune_paths_collect() {
  dune_ensure_bottle_env
  DUNE_PATHS_PREFIX="$(crossover_bottle_dir 2>/dev/null || true)"
  DUNE_PATHS_BOTTLE_ROOT="$(crossover_bottle_root_dir 2>/dev/null || true)"
  DUNE_PATHS_WINE="$(crossover_wine_bin 2>/dev/null || true)"
  DUNE_PATHS_STEAM="$(dune_steam_exe_path 2>/dev/null || true)"
  DUNE_PATHS_GAME_ROOT="$(dune_game_root 2>/dev/null || true)"
  DUNE_PATHS_LAUNCHER="$(dune_launcher_exe 2>/dev/null || true)"
  DUNE_PATHS_BE_WRAPPER="$(dune_be_wrapper_exe 2>/dev/null || true)"
  DUNE_PATHS_BE_DIR="$(dune_battleye_dir 2>/dev/null || true)"
  DUNE_PATHS_BE_CACHE="$(dune_be_appdata_cache_dir 2>/dev/null || true)"
  DUNE_PATHS_CXBOTTLE="$(dune_cxbottle_conf 2>/dev/null || true)"
}

dune_paths_print() {
  dune_paths_collect
  printf '%-22s %s\n' "bottle_name" "$(dune_bottle_name)"
  printf '%-22s %s\n' "steam_appid" "${DUNE_STEAM_APPID}"
  printf '%-22s %s\n' "crossover_prefix" "${DUNE_PATHS_PREFIX:-<unset>}"
  printf '%-22s %s\n' "bottle_root" "${DUNE_PATHS_BOTTLE_ROOT:-<unset>}"
  printf '%-22s %s\n' "crossover_wine" "${DUNE_PATHS_WINE:-<unset>}"
  printf '%-22s %s\n' "steam_exe" "${DUNE_PATHS_STEAM:-<unset>}"
  printf '%-22s %s\n' "game_root" "${DUNE_PATHS_GAME_ROOT:-<unset>}"
  printf '%-22s %s\n' "launcher_exe" "${DUNE_PATHS_LAUNCHER:-<unset>}"
  printf '%-22s %s\n' "be_wrapper_exe" "${DUNE_PATHS_BE_WRAPPER:-<unset>}"
  printf '%-22s %s\n' "battleye_dir" "${DUNE_PATHS_BE_DIR:-<unset>}"
  printf '%-22s %s\n' "be_appdata_cache" "${DUNE_PATHS_BE_CACHE:-<unset>}"
  printf '%-22s %s\n' "cxbottle_conf" "${DUNE_PATHS_CXBOTTLE:-<unset>}"
}

dune_paths_json() {
  dune_paths_collect
  printf '{'
  printf '"bottle_name":%s,' "$(dune_paths_json_quote "$(dune_bottle_name)")"
  printf '"steam_appid":%s,' "$(dune_paths_json_quote "${DUNE_STEAM_APPID}")"
  printf '"crossover_prefix":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_PREFIX}")"
  printf '"bottle_root":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_BOTTLE_ROOT}")"
  printf '"crossover_wine":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_WINE}")"
  printf '"steam_exe":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_STEAM}")"
  printf '"game_root":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_GAME_ROOT}")"
  printf '"be_wrapper_exe":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_BE_WRAPPER}")"
  printf '"battleye_dir":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_BE_DIR}")"
  printf '"be_appdata_cache":%s,' "$(dune_paths_json_quote "${DUNE_PATHS_BE_CACHE}")"
  printf '"cxbottle_conf":%s' "$(dune_paths_json_quote "${DUNE_PATHS_CXBOTTLE}")"
  printf '}\n'
}

dune_bottle_env_configured() {
  local conf key="$1"
  if ! conf="$(dune_cxbottle_conf 2>/dev/null)" || [[ ! -f "$conf" ]]; then
    return 1
  fi
  grep -Fq "\"${key}\"" "$conf"
}

dune_doctor() {
  local ok=0
  local check_bottle=false

  if [[ -n "${CROSSOVER_BOTTLE:-}" || -n "${CROSSOVER_PREFIX:-}" || "${DUNE_STRICT_DOCTOR:-0}" == "1" ]]; then
    check_bottle=true
    dune_ensure_bottle_env
  fi

  if crossover_support_root >/dev/null 2>&1; then
    log_info "CrossOver installed: $(crossover_support_root)"
  else
    log_warn "CrossOver not found under /Applications/CrossOver.app"
    if [[ "$check_bottle" == true ]]; then
      ok=1
    fi
  fi

  if crossover_wine_bin >/dev/null 2>&1; then
    log_info "wine CLI: $(crossover_wine_bin)"
  elif [[ "$check_bottle" == true ]]; then
    log_warn "CrossOver wine binary not found"
    ok=1
  fi

  if dune_host_is_apple_silicon; then
    if dune_bottle_env_configured "ROSETTA_ADVERTISE_AVX"; then
      log_info "ROSETTA_ADVERTISE_AVX set in cxbottle.conf"
    else
      log_warn "ROSETTA_ADVERTISE_AVX not set — run: task dune:configure (Advertise AVX capabilities)"
      if [[ "$check_bottle" == true ]]; then
        ok=1
      fi
    fi
  fi

  if [[ "$check_bottle" == true ]]; then
    if crossover_bottle_exists; then
      log_info "Bottle exists: $(crossover_bottle_root_dir)"
      if prefix="$(crossover_bottle_dir 2>/dev/null)" && [[ -d "$prefix" ]]; then
        log_info "CrossOver drive_c: $prefix"
      fi

      if steam="$(dune_steam_exe_path 2>/dev/null)"; then
        log_info "Steam in bottle: $steam"
      else
        log_warn "Steam not found in bottle — install Steam crosstie via CrossOver"
        ok=1
      fi

      if launcher="$(dune_launcher_exe 2>/dev/null)" && [[ -f "$launcher" ]]; then
        log_info "Game launcher: $launcher"
      else
        log_warn "DuneSandbox.exe not found — install Dune: Awakening via Steam"
        ok=1
      fi

      if wrapper="$(dune_be_wrapper_exe 2>/dev/null)" && [[ -f "$wrapper" ]]; then
        log_info "BattlEye wrapper: $wrapper"
      else
        log_warn "DuneSandbox_BE.exe not found"
        ok=1
      fi

      if be_dir="$(dune_battleye_dir 2>/dev/null)" && [[ -d "$be_dir" ]]; then
        if [[ -f "${be_dir}/BEClient_x64.dll" && -f "${be_dir}/BEService_x64.exe" ]]; then
          log_info "BattlEye game files present: $be_dir"
        else
          log_warn "BattlEye game folder incomplete: $be_dir"
          ok=1
        fi
      else
        log_warn "BattlEye game folder missing"
        ok=1
      fi

      if cache="$(dune_be_appdata_cache_dir 2>/dev/null)"; then
        if [[ -d "$cache" && -f "${cache}/BEService_x64.exe" ]]; then
          log_info "BattlEye AppData cache: $cache"
        else
          log_warn "BattlEye AppData cache missing or incomplete (run: task dune:fix-battleye)"
          ok=1
        fi
      fi

      if dune_battleye_service_query >/dev/null 2>&1; then
        log_info "BEService query: $(dune_battleye_service_query 2>/dev/null | tr '\n' ' ')"
        if ! dune_battleye_service_is_running; then
          log_warn "BEService registered but not RUNNING (run: task dune:fix-battleye)"
          ok=1
        fi
      else
        log_warn "BEService not queryable via sc.exe (run: task dune:fix-battleye)"
        ok=1
      fi
    else
      log_error "Bottle not found: ${CROSSOVER_BOTTLE} (create via CrossOver GUI)"
      ok=1
    fi
  else
    log_info "Set CROSSOVER_BOTTLE or DUNE_STRICT_DOCTOR=1 to check bottle/game/BattlEye"
  fi

  return "$ok"
}
