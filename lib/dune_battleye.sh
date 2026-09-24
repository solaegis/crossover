# shellcheck shell=bash
# Dune: Awakening BattlEye repair and service helpers.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "dune_battleye.sh is a library; source it instead of executing." >&2
  exit 1
fi

dune_battleye_service_query() {
  dune_run_cmd sc.exe query BEService 2>/dev/null
}

dune_battleye_service_stop() {
  log_info "Stopping BEService via sc.exe (if running)..."
  dune_run_cmd sc.exe stop BEService >/dev/null 2>&1 || true
}

dune_battleye_read_cached_version() {
  local cache ini line
  if ! cache="$(dune_be_appdata_cache_dir 2>/dev/null)"; then
    return 0
  fi
  ini="${cache}/BELauncher.ini"
  [[ -f "$ini" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    if [[ "$line" =~ ^CachedVersion=(.+)$ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done <"$ini"
}

dune_battleye_service_start() {
  log_info "Starting BEService via sc.exe..."
  if dune_run_cmd sc.exe start BEService; then
    log_info "BEService start requested"
    return 0
  fi
  log_warn "sc.exe start BEService failed — trying direct BEService_x64.exe"
  dune_battleye_start_service_direct || return 1
}

dune_battleye_start_service_direct() {
  local service_exe common
  if service_exe="$(dune_be_service_x64_exe 2>/dev/null)" && [[ -f "$service_exe" ]]; then
    log_info "Launching BEService_x64.exe from game BattlEye dir (background attempt)"
    dune_run_cmd \
      --workdir 'C:\Program Files (x86)\Steam\steamapps\common\DuneAwakening\DuneSandbox\Binaries\Win64\BattlEye' \
      --cx-app "BEService_x64.exe" &
    return 0
  fi
  if common="$(dune_be_service_exe 2>/dev/null)" && [[ -f "$common" ]]; then
    log_info "Launching BEService.exe from Common Files (background attempt)"
    dune_run_cmd \
      --workdir 'C:\Program Files (x86)\Common Files\BattlEye' \
      --cx-app "BEService.exe" &
    return 0
  fi
  log_error "No BEService executable found to start"
  return 1
}

dune_battleye_sync_common_service() {
  local src common be_x64
  if ! src="$(dune_be_service_x64_exe 2>/dev/null)" || [[ ! -f "$src" ]]; then
    log_warn "BEService_x64.exe missing in game BattlEye folder — skip sync"
    return 0
  fi
  if ! common="$(dune_common_battleye_dir 2>/dev/null)"; then
    return 1
  fi
  mkdir -p "$common"
  be_x64="${common}/BEService.exe"
  if [[ ! -f "$be_x64" ]] || ! cmp -s "$src" "$be_x64" 2>/dev/null; then
    cp -f "$src" "$be_x64"
    log_info "Synced BEService.exe in Common Files from game BattlEye dir"
  fi
  cp -f "$src" "${common}/BEService_dune.exe" 2>/dev/null || true
}

dune_battleye_clear_appdata_cache() {
  local cache
  if ! cache="$(dune_be_appdata_cache_dir 2>/dev/null)"; then
    return 0
  fi
  if [[ -d "$cache" ]]; then
    rm -rf "$cache"
    log_info "Removed BattlEye AppData cache: $cache"
  fi
}

dune_battleye_seed_appdata_cache() {
  local cache be_dir src cached_version
  cached_version="${DUNE_BE_CACHED_VERSION:-}"
  if ! cache="$(dune_be_appdata_cache_dir 2>/dev/null)"; then
    return 0
  fi
  if ! be_dir="$(dune_battleye_dir 2>/dev/null)" || [[ ! -d "$be_dir" ]]; then
    return 0
  fi
  mkdir -p "$cache"
  shopt -s nullglob
  for src in "${be_dir}"/*; do
    [[ -f "$src" ]] || continue
    cp -f "$src" "${cache}/$(basename "$src")"
  done
  shopt -u nullglob
  dune_battleye_write_consent_ini "$cached_version"
  if [[ -f "${cache}/BEService_x64.exe" ]]; then
    log_info "Seeded BattlEye AppData cache from game BattlEye dir"
  fi
}

dune_battleye_write_consent_ini() {
  local cache cached_version="${1:-}"
  if ! cache="$(dune_be_appdata_cache_dir 2>/dev/null)"; then
    return 0
  fi
  mkdir -p "$cache"
  if [[ -n "$cached_version" ]]; then
    cat >"${cache}/BELauncher.ini" <<EOF
[Launcher]
UserConsentReceived=1
CachedVersion=${cached_version}
EOF
    log_info "Wrote BELauncher.ini (UserConsentReceived=1, CachedVersion=${cached_version})"
    return 0
  fi
  cat >"${cache}/BELauncher.ini" <<'EOF'
[Launcher]
UserConsentReceived=1
EOF
  log_info "Wrote BELauncher.ini with UserConsentReceived=1"
}

dune_battleye_run_uninstall() {
  local bat
  if ! bat="$(dune_battleye_uninstall_bat 2>/dev/null)" || [[ ! -f "$bat" ]]; then
    log_warn "Uninstall_BattlEye.bat not found — skipping uninstall"
    return 0
  fi
  log_info "Running Uninstall_BattlEye.bat..."
  dune_run_cmd \
    --workdir 'C:\Program Files (x86)\Steam\steamapps\common\DuneAwakening\DuneSandbox\Binaries\Win64\BattlEye' \
    cmd /c Uninstall_BattlEye.bat || log_warn "Uninstall_BattlEye.bat returned non-zero (continuing)"
}

dune_battleye_service_is_running() {
  dune_battleye_service_query 2>/dev/null | grep -q 'STATE[[:space:]]*:[[:space:]]*4[[:space:]]*RUNNING'
}

dune_battleye_register_service_sc() {
  local common service_win
  if ! common="$(dune_be_service_exe 2>/dev/null)" || [[ ! -f "$common" ]]; then
    log_error "BEService.exe missing in Common Files — sync game BattlEye files first"
    return 1
  fi
  service_win="$(dune_battleye_win_path "$common")"
  log_info "Registering BEService via sc.exe (Wine-compatible install)..."
  dune_run_cmd sc.exe stop BEService >/dev/null 2>&1 || true
  if dune_battleye_service_query >/dev/null 2>&1; then
    log_info "BEService already registered — updating binPath via sc.exe config"
    dune_run_cmd sc.exe config BEService \
      binPath= "$service_win" \
      start= auto >/dev/null 2>&1 || true
  else
    if ! dune_run_cmd sc.exe create BEService \
      binPath= "$service_win" \
      start= auto \
      DisplayName= "BattlEye Service"; then
      log_error "sc.exe create BEService failed"
      return 1
    fi
    log_info "BEService created via sc.exe"
  fi
}

dune_battleye_run_install() {
  local bat
  if bat="$(dune_battleye_install_bat 2>/dev/null)" && [[ -f "$bat" ]]; then
    log_info "Running Install_BattlEye.bat (may fail under Wine — sc.exe fallback follows)..."
    if dune_run_cmd \
      --workdir 'C:\Program Files (x86)\Steam\steamapps\common\DuneAwakening\DuneSandbox\Binaries\Win64\BattlEye' \
      cmd /c Install_BattlEye.bat; then
      return 0
    fi
    log_warn "Install_BattlEye.bat failed (4, 40000430 is common under CrossOver/Wine)"
  fi
  dune_battleye_register_service_sc
}

dune_battleye_win_path() {
  local path="$1"
  local drive_c
  if ! drive_c="$(dune_drive_c 2>/dev/null)"; then
    printf '%s\n' "$path"
    return 0
  fi
  if [[ "$path" == "${drive_c}/"* ]]; then
    local rel="${path#"${drive_c}/"}"
    rel="${rel//\//\\}"
    printf 'C:\\%s\n' "$rel"
    return 0
  fi
  printf '%s\n' "$path"
}

dune_battleye_full_reset_game_dir() {
  local be_dir
  if ! be_dir="$(dune_battleye_dir 2>/dev/null)"; then
    return 0
  fi
  if [[ -d "$be_dir" ]]; then
    rm -rf "$be_dir"
    log_info "Removed game BattlEye directory: $be_dir"
  fi
}

dune_battleye_print_steam_verify_steps() {
  log_heading "Steam verify required after --full-reset:"
  echo >&2
  log_step 1 "Run: task dune:verify-steam  (or open Steam manually)"
  log_step 2 "Wait for verify to finish (restores the BattlEye/ folder)"
  log_step 3 "Re-run: task dune:fix-battleye"
  echo >&2
}

dune_verify_steam() {
  dune_ensure_bottle_env
  if ! crossover_bottle_exists; then
    log_error "Bottle not found: $(dune_bottle_name)"
    return 1
  fi
  if ! crossover_wine_bin >/dev/null 2>&1; then
    log_error "CrossOver wine binary not found"
    return 1
  fi
  log_info "Launching Steam verify for Dune: Awakening (AppID 1172710)..."
  log_info "Complete the verify in Steam, then run: task dune:fix-battleye"
  dune_run_cmd --cx-app steam.exe steam://validate/1172710
}

dune_battleye_fix() {
  local full_reset=false
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full-reset)
        full_reset=true
        shift
        ;;
      *)
        log_error "unknown fix-battleye option: $1"
        return 2
        ;;
    esac
  done

  dune_ensure_bottle_env

  if ! crossover_bottle_exists; then
    log_error "Bottle not found: $(dune_bottle_name)"
    return 1
  fi

  if ! crossover_wine_bin >/dev/null 2>&1; then
    log_error "CrossOver wine binary not found"
    return 1
  fi

  log_info "=== BattlEye fix (bottle: ${CROSSOVER_BOTTLE}) ==="

  DUNE_BE_CACHED_VERSION="$(dune_battleye_read_cached_version || true)"
  export DUNE_BE_CACHED_VERSION

  dune_battleye_service_stop
  dune_battleye_run_uninstall
  dune_battleye_clear_appdata_cache

  if [[ "$full_reset" == true ]]; then
    dune_battleye_full_reset_game_dir
    dune_battleye_print_steam_verify_steps
    log_info "Full reset complete — next: task dune:verify-steam, then task dune:fix-battleye"
    return 0
  fi

  if ! dune_battleye_dir >/dev/null 2>&1 || [[ ! -d "$(dune_battleye_dir)" ]]; then
    log_error "BattlEye game folder missing — run with --full-reset, verify in Steam, then re-run fix"
    return 1
  fi

  dune_battleye_sync_common_service
  dune_battleye_run_install || return 1
  dune_battleye_seed_appdata_cache
  dune_battleye_service_start || log_warn "BEService start uncertain — try launching the game"

  log_info "=== BattlEye fix finished; running doctor ==="
  DUNE_STRICT_DOCTOR=1 dune_doctor || true
}
