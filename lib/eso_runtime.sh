# shellcheck shell=bash
# ESO recipe: bottle defaults, paths display, launch, doctor.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "eso_runtime.sh is a library; source it instead of executing." >&2
  exit 1
fi

ESO_DEFAULT_BOTTLE_NAME="${ESO_DEFAULT_BOTTLE_NAME:-The Elder Scrolls Online (Steam)}"
ESO_MINION_JAR_NAME="${ESO_MINION_JAR_NAME:-Minion-jfx.jar}"
ESO_MINION_MAC_APP="${ESO_MINION_MAC_APP:-/Applications/Minion.app}"
ESO_STEAM_APPID="${ESO_STEAM_APPID:-306130}"
ESO_TTC_WIN_WORKDIR='C:\users\crossover\Documents\Elder Scrolls Online\live\AddOns\TamrielTradeCentre\Client'
ESO_TTC_WIN_EXE='C:\users\crossover\Documents\Elder Scrolls Online\live\AddOns\TamrielTradeCentre\Client\Client.exe'
ESO_TTC_HOSTS_BEGIN='# BEGIN solaegis-ttc'
ESO_TTC_HOSTS_END='# END solaegis-ttc'
ESO_TTC_HOSTS_IP='104.168.135.156'
ESO_TTC_HOSTS=(
  www.tamrieltradecentre.com
  us.tamrieltradecentre.com
  eu.tamrieltradecentre.com
)
ESO_TTC_HTTPS_URLS=(
  https://www.tamrieltradecentre.com/
  https://us.tamrieltradecentre.com/
)
# Microsoft .NET 4.8 Release dword minimum (decimal 528040)
ESO_TTC_DOTNET48_RELEASE_MIN=528040
ESO_TTC_DOTNET48_APPID='com.codeweavers.c4.16255'

eso_bottle_name() {
  printf '%s\n' "${CROSSOVER_BOTTLE:-${ESO_DEFAULT_BOTTLE_NAME}}"
}

eso_ensure_bottle_env() {
  export CROSSOVER_BOTTLE="${CROSSOVER_BOTTLE:-$(eso_bottle_name)}"
}

eso_mac_live_dir() {
  local addons
  if addons="$(eso_mac_addons_dir 2>/dev/null)"; then
    dirname "$addons"
    return 0
  fi
  printf '%s/Documents/Elder Scrolls Online/live\n' "${HOME}"
}

eso_minion_mac_app_resources_dir() {
  printf '%s/Contents/Resources\n' "${ESO_MINION_MAC_APP}"
}

eso_minion_mac_app_available() {
  local resources jar lib_dir
  resources="$(eso_minion_mac_app_resources_dir)"
  jar="${resources}/${ESO_MINION_JAR_NAME}"
  lib_dir="${resources}/lib"
  [[ -d "${ESO_MINION_MAC_APP}" && -f "$jar" && -d "$lib_dir" ]]
}

eso_steam_exe_candidates() {
  local drive_c
  if ! drive_c="$(crossover_bottle_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/Program Files (x86)/Steam/steam.exe\n' "$drive_c"
  printf '%s/Program Files/Steam/steam.exe\n' "$drive_c"
}

eso_steam_exe_path() {
  local candidate
  while IFS= read -r candidate; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(eso_steam_exe_candidates)
  return 1
}

eso_steam_cx_app() {
  local path
  if path="$(eso_steam_exe_path 2>/dev/null)"; then
    basename "$path"
    return 0
  fi
  printf '%s\n' "steam.exe"
}

eso_run() {
  local wine bottle cx_app
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  eso_ensure_bottle_env
  bottle="${CROSSOVER_BOTTLE}"
  cx_app="${1:?cx-app executable required}"
  shift
  "$wine" --bottle "$bottle" --cx-app "$cx_app" "$@"
}

eso_launch_steam() {
  eso_run "$(eso_steam_cx_app)"
}

eso_launch_minion() {
  eso_ensure_bottle_env
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "Minion launch requires macOS (native Minion.app)"
    return 1
  fi
  if ! eso_minion_mac_app_available; then
    log_error "Minion.app not found at ${ESO_MINION_MAC_APP} — install Minion for Mac or set ESO_MINION_MAC_APP"
    return 1
  fi
  log_info "Launching Minion.app (point AddOns at: $(eso_mac_addons_dir 2>/dev/null || eso_default_mac_addons))"
  open -a "${ESO_MINION_MAC_APP}"
}

eso_ttc_client_dir() {
  local addons
  if ! addons="$(eso_mac_addons_dir 2>/dev/null)"; then
    addons="$(eso_default_mac_addons)"
  fi
  printf '%s/TamrielTradeCentre/Client\n' "$addons"
}

eso_ttc_client_exe() {
  printf '%s/Client.exe\n' "$(eso_ttc_client_dir)"
}

eso_ttc_lock_path() {
  printf '%s/TTC_Lock\n' "$(eso_ttc_client_dir)"
}

eso_ttc_mac_helper_app() {
  if [[ -n "${ESO_TTC_MAC_HELPER_APP:-}" ]]; then
    printf '%s\n' "${ESO_TTC_MAC_HELPER_APP}"
    return 0
  fi
  printf '%s/Applications/CrossOver/Tamriel Trade Centre Client.app\n' "${HOME}"
}

eso_ttc_client_available() {
  local exe
  exe="$(eso_ttc_client_exe)"
  [[ -f "$exe" ]]
}

eso_clear_ttc_lock() {
  local lock
  lock="$(eso_ttc_lock_path)"
  if [[ -e "$lock" ]]; then
    rm -f "$lock" && log_info "Removed TTC lock: $lock"
  fi
}

eso_awake_off() {
  if command -v awake >/dev/null 2>&1; then
    awake off >/dev/null 2>&1 || true
    log_info "awake off"
  fi
}

eso_awake_on() {
  if command -v awake >/dev/null 2>&1; then
    awake >/dev/null 2>&1 || true
    log_info "awake on"
  fi
}

eso_launch_ttc() {
  local exe wine
  eso_ensure_bottle_env
  if ! exe="$(eso_ttc_client_exe)" || [[ ! -f "$exe" ]]; then
    log_error "TTC Client.exe not found at $(eso_ttc_client_exe)"
    return 1
  fi
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  log_info "Launching Tamriel Trade Centre Client in bottle ${CROSSOVER_BOTTLE}"
  # Match CrossOver Start Menu shortcut: workdir + Client.exe (do not use --no-update here —
  # first launch after bottle upgrade may need a bottle update).
  "$wine" --bottle "${CROSSOVER_BOTTLE}" --check --wait-children \
    --workdir "${ESO_TTC_WIN_WORKDIR}" \
    "${ESO_TTC_WIN_EXE}" "$@"
}

# Detached Steam + TTC for a play session (returns immediately; use eso_stop / eso quit to exit).
eso_start() {
  local wine cx_app exe helper
  eso_ensure_bottle_env

  if ! crossover_bottle_exists; then
    log_error "Bottle not found: ${CROSSOVER_BOTTLE}"
    return 1
  fi
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  if ! exe="$(eso_ttc_client_exe)" || [[ ! -f "$exe" ]]; then
    log_error "TTC Client.exe not found at $(eso_ttc_client_exe)"
    return 1
  fi

  cx_app="$(eso_steam_cx_app)"
  log_info "=== eso start (bottle: ${CROSSOVER_BOTTLE}) ==="
  eso_awake_on

  # nohup + redirect: Task/shell exit must not SIGHUP Steam/TTC children.
  log_info "Launching Steam (detached)"
  nohup "$wine" --bottle "${CROSSOVER_BOTTLE}" --cx-app "$cx_app" \
    </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true

  # Prefer CrossOver Mac helper so TTC is LaunchServices-detached (survives task exit).
  helper="$(eso_ttc_mac_helper_app)"
  if [[ "$(uname -s)" == "Darwin" && -d "$helper" ]]; then
    log_info "Launching Tamriel Trade Centre Client (Mac helper: $helper)"
    open -a "$helper"
  else
    log_info "Launching Tamriel Trade Centre Client (detached wine)"
    nohup "$wine" --bottle "${CROSSOVER_BOTTLE}" --check \
      --workdir "${ESO_TTC_WIN_WORKDIR}" \
      "${ESO_TTC_WIN_EXE}" \
      </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  log_info "Steam + TTC started — launch ESO from Steam, then: task eso:stop"
  log_info "Status: task eso:status"
}

eso_stop() {
  eso_quit "$@"
}

eso_status_match_count() {
  local pattern="${1:?pattern required}"
  local lines
  lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
  if [[ -z "$lines" ]]; then
    printf '0\n'
    return 0
  fi
  printf '%s\n' "$lines" | grep -ciE "$pattern" || true
}

eso_status_print() {
  local bottle lines eso_n ttc_n steam_n wine_n lock
  eso_ensure_bottle_env
  bottle="$(eso_bottle_name)"

  printf '%-20s %s\n' "bottle_name" "$bottle"
  if crossover_bottle_exists; then
    printf '%-20s %s\n' "bottle_root" "$(crossover_bottle_root_dir)"
  else
    printf '%-20s %s\n' "bottle_root" "<missing>"
  fi

  lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
  eso_n="$(eso_status_match_count 'eso64')"
  ttc_n="$(eso_status_match_count 'Client\.exe|TamrielTradeCentre|/Client')"
  steam_n="$(eso_status_match_count 'steam\.exe|Steam')"
  wine_n=0
  if [[ -n "$lines" ]]; then
    wine_n="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
  fi

  printf '%-20s %s\n' "eso64" "$eso_n"
  printf '%-20s %s\n' "ttc_client" "$ttc_n"
  printf '%-20s %s\n' "steam" "$steam_n"
  printf '%-20s %s\n' "bottle_procs" "$wine_n"
  if crossover_wineserver_running 2>/dev/null; then
    printf '%-20s %s\n' "wineserver" "running"
  else
    printf '%-20s %s\n' "wineserver" "idle"
  fi

  lock="$(eso_ttc_lock_path)"
  if [[ -e "$lock" ]]; then
    printf '%-20s %s\n' "ttc_lock" "present ($lock)"
  else
    printf '%-20s %s\n' "ttc_lock" "absent"
  fi

  if [[ -n "$lines" ]]; then
    echo
    echo "processes:"
    printf '%s\n' "$lines"
  fi
}

eso_status_is_busy() {
  local lines
  lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
  [[ -n "$lines" ]]
}

eso_quit_game_only() {
  log_info "Quitting ESO + TTC (keeping Steam) in bottle ${CROSSOVER_BOTTLE}"
  crossover_taskkill "eso64.exe"
  crossover_taskkill "Client.exe"
  # Brief wait for processes to drop
  sleep 1
  eso_clear_ttc_lock
  eso_awake_off
}

eso_quit_full() {
  log_info "Ending Windows session for bottle ${CROSSOVER_BOTTLE}"
  if crossover_wine_bin >/dev/null 2>&1 && crossover_bottle_exists; then
    crossover_wineboot_end >/dev/null 2>&1 || true
    sleep 1
    if eso_status_is_busy; then
      log_warn "Processes still running; killing wineserver"
      crossover_wineserver_kill >/dev/null 2>&1 || true
      sleep 1
    fi
  else
    log_warn "CrossOver/bottle unavailable; skipping wineboot/wineserver"
  fi
  eso_clear_ttc_lock
  eso_awake_off
}

eso_quit() {
  local keep_steam=false
  local -a args=()
  log_filter_argv args "$@"
  set -- "${args[@]}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-steam)
        keep_steam=true
        shift
        ;;
      *)
        log_error "unknown quit option: $1 (use --keep-steam)"
        return 2
        ;;
    esac
  done

  eso_ensure_bottle_env

  if [[ "$keep_steam" == true ]]; then
    eso_quit_game_only
  else
    eso_quit_full
  fi

  eso_status_print
  if eso_status_is_busy; then
    log_warn "Bottle still has processes — check status output above"
    return 1
  fi
  log_info "Bottle idle"
  return 0
}

eso_paths_collect() {
  eso_ensure_bottle_env
  ESO_PATHS_MAC="$(eso_mac_addons_dir 2>/dev/null || true)"
  ESO_PATHS_WIN="$(eso_win_addons_dir 2>/dev/null || true)"
  ESO_PATHS_PREFIX="$(crossover_bottle_dir 2>/dev/null || true)"
  ESO_PATHS_BOTTLE_ROOT="$(crossover_bottle_root_dir 2>/dev/null || true)"
  ESO_PATHS_WINE="$(crossover_wine_bin 2>/dev/null || true)"
  ESO_PATHS_MINION_MAC_APP="${ESO_MINION_MAC_APP}"
  ESO_PATHS_STEAM="$(eso_steam_exe_path 2>/dev/null || true)"
}

eso_paths_print() {
  eso_paths_collect
  printf '%-20s %s\n' "bottle_name" "$(eso_bottle_name)"
  printf '%-20s %s\n' "mac_addons" "${ESO_PATHS_MAC:-<unset>}"
  printf '%-20s %s\n' "win_addons" "${ESO_PATHS_WIN:-<unset>}"
  printf '%-20s %s\n' "crossover_prefix" "${ESO_PATHS_PREFIX:-<unset>}"
  printf '%-20s %s\n' "bottle_root" "${ESO_PATHS_BOTTLE_ROOT:-<unset>}"
  printf '%-20s %s\n' "crossover_wine" "${ESO_PATHS_WINE:-<unset>}"
  printf '%-20s %s\n' "steam_exe" "${ESO_PATHS_STEAM:-<unset>}"
  printf '%-20s %s\n' "minion_mac_app" "${ESO_PATHS_MINION_MAC_APP:-<unset>}"
}

eso_paths_extended_json() {
  eso_paths_collect
  printf '{'
  printf '"bottle_name":%s,' "$(eso_paths_json_quote "$(eso_bottle_name)")"
  printf '"mac_addons":%s,' "$(eso_paths_json_quote "${ESO_PATHS_MAC}")"
  printf '"win_addons":%s,' "$(eso_paths_json_quote "${ESO_PATHS_WIN}")"
  printf '"crossover_prefix":%s,' "$(eso_paths_json_quote "${ESO_PATHS_PREFIX}")"
  printf '"bottle_root":%s,' "$(eso_paths_json_quote "${ESO_PATHS_BOTTLE_ROOT}")"
  printf '"crossover_wine":%s,' "$(eso_paths_json_quote "${ESO_PATHS_WINE}")"
  printf '"minion_mac_app":%s,' "$(eso_paths_json_quote "${ESO_PATHS_MINION_MAC_APP}")"
  printf '"steam_exe":%s' "$(eso_paths_json_quote "${ESO_PATHS_STEAM}")"
  printf '}\n'
}

eso_ttc_errorlog_dir() {
  printf '%s/ErrorLog\n' "$(eso_ttc_client_dir)"
}

eso_ttc_hosts_body() {
  local host
  for host in "${ESO_TTC_HOSTS[@]}"; do
    printf '%s %s\n' "${ESO_TTC_HOSTS_IP}" "$host"
  done
}

eso_ttc_hosts_apply() {
  eso_ensure_bottle_env
  eso_ttc_hosts_body | crossover_hosts_apply_block "${ESO_TTC_HOSTS_BEGIN}" "${ESO_TTC_HOSTS_END}"
  log_info "Pinned TTC hosts in $(crossover_bottle_hosts_path)"
}

eso_ttc_hosts_present() {
  eso_ensure_bottle_env
  crossover_hosts_block_present "${ESO_TTC_HOSTS_BEGIN}"
}

# Host HTTPS probe. Returns 0 if all URLs succeed.
eso_ttc_probe_host_https() {
  local url
  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl not found; skipping host HTTPS probe"
    return 1
  fi
  for url in "${ESO_TTC_HTTPS_URLS[@]}"; do
    if curl -fsS --connect-timeout 5 -o /dev/null "$url"; then
      log_info "Host HTTPS OK: $url"
    else
      log_warn "Host HTTPS FAILED: $url"
      return 1
    fi
  done
  return 0
}

# Wine DNS probe via ping (nslookup is often absent). ICMP may time out; we only need resolution.
eso_ttc_probe_wine_dns() {
  local out
  eso_ensure_bottle_env
  if ! crossover_wine_bin >/dev/null 2>&1 || ! crossover_bottle_exists; then
    log_warn "Wine/bottle unavailable; skipping Wine DNS probe"
    return 1
  fi
  out="$(crossover_run_wine ping -n 1 www.tamrieltradecentre.com 2>&1 || true)"
  if printf '%s\n' "$out" | grep -qF "${ESO_TTC_HOSTS_IP}"; then
    log_info "Wine DNS OK: www.tamrieltradecentre.com → ${ESO_TTC_HOSTS_IP}"
    return 0
  fi
  log_warn "Wine DNS probe did not report ${ESO_TTC_HOSTS_IP}"
  printf '%s\n' "$out" | sed -n '1,12p' >&2 || true
  return 1
}

# Summarize TTC Client ErrorLog (dns vs timeout). Prints counts; returns 0 always.
eso_ttc_errorlog_summary() {
  local dir today log dns_n timeout_n
  dir="$(eso_ttc_errorlog_dir)"
  if [[ ! -d "$dir" ]]; then
    log_info "TTC ErrorLog dir missing: $dir"
    return 0
  fi
  today="$(date +%Y-%m-%d)"
  log="${dir}/${today}.log"
  if [[ ! -f "$log" ]]; then
    # fall back to newest log
    log="$(find "$dir" -maxdepth 1 -name '*.log' -type f -print 2>/dev/null | sort | tail -1 || true)"
  fi
  if [[ -z "$log" || ! -f "$log" ]]; then
    log_info "TTC ErrorLog: no log files"
    return 0
  fi
  dns_n="$(grep -c 'NameResolutionFailure' "$log" 2>/dev/null || true)"
  timeout_n="$(grep -c 'timed out\|The operation has timed out' "$log" 2>/dev/null || true)"
  dns_n="${dns_n:-0}"
  timeout_n="${timeout_n:-0}"
  log_info "TTC ErrorLog $(basename "$log"): NameResolutionFailure=${dns_n} timeout=${timeout_n}"
}

# True if NDP v4 Full Release >= ESO_TTC_DOTNET48_RELEASE_MIN in system.reg
eso_ttc_dotnet48_installed() {
  local reg release
  eso_ensure_bottle_env
  reg="$(crossover_bottle_root_dir 2>/dev/null)/system.reg"
  if [[ ! -f "$reg" ]]; then
    return 1
  fi
  # Prefer Wow6432/NDP/v4/Full Release dword (hex)
  release="$(awk '
    /\[Software\\\\Microsoft\\\\NET Framework Setup\\\\NDP\\\\v4\\\\Full\]/ { insec=1; next }
    /^\[/ { insec=0 }
    insec && /\"Release\"=dword:/ {
      sub(/.*dword:/, "", $0)
      print $0
      exit
    }
  ' "$reg")"
  if [[ -z "$release" ]]; then
    return 1
  fi
  # hex to decimal
  release=$((16#${release}))
  [[ "$release" -ge "${ESO_TTC_DOTNET48_RELEASE_MIN}" ]]
}

eso_ttc_dotnet48_guidance() {
  local tie
  if eso_ttc_dotnet48_installed; then
    log_info ".NET Framework 4.8 present in bottle (NDP v4 Full Release OK)"
    return 0
  fi
  log_warn ".NET Framework 4.8 not detected in bottle registry"
  log_info "CrossOver → Install a Windows Application → Microsoft .NET Framework 4.8 → bottle ${CROSSOVER_BOTTLE:-$(eso_bottle_name)}"
  log_info "(appid ${ESO_TTC_DOTNET48_APPID}; or open ties/ttc_client.tie — notes +.NET only, not a Client.exe installer)"
  if tie="$(crossover_tie_path ttc_client 2>/dev/null)"; then
    log_info "Crosstie path: ${tie}"
  fi
  log_info "If CrossOver says the .tie is an unknown installer type: Cancel Installation, then install .NET 4.8 from the catalog by name"
  return 1
}

eso_ttc_menu_guidance() {
  local helper
  helper="$(eso_ttc_mac_helper_app)"
  if [[ -d "$helper" ]]; then
    log_info "TTC Mac helper present: $helper"
    return 0
  fi
  log_warn "TTC Mac helper missing — refresh menus:"
  log_info "  cxmenu --bottle \"$(eso_bottle_name)\" --install"
  log_info "Or open $(crossover_tie_path ttc_client 2>/dev/null || echo ties/ttc_client.tie)"
  return 1
}

eso_fix_ttc_net() {
  local ok=0
  eso_ensure_bottle_env
  log_info "=== eso fix-ttc-net (bottle: ${CROSSOVER_BOTTLE}) ==="

  if ! crossover_bottle_exists; then
    log_error "Bottle not found: ${CROSSOVER_BOTTLE}"
    return 1
  fi

  if ! eso_ttc_probe_host_https; then
    log_error "Host cannot reach TTC — fix Mac network/DNS before bottle tweaks"
    ok=1
  fi

  eso_ttc_hosts_apply || ok=1
  eso_ttc_probe_wine_dns || true
  eso_ttc_errorlog_summary || true
  eso_ttc_dotnet48_guidance || true
  eso_ttc_menu_guidance || true
  eso_clear_ttc_lock

  log_info "Re-test: crossover eso launch ttc  (then check Client/ErrorLog)"
  log_info "Clean exit: crossover eso quit"
  return "$ok"
}

eso_doctor() {
  local ok=0
  local check_bottle=false
  local mac win steam bottle ttc_exe ttc_lock ttc_helper

  if [[ -n "${CROSSOVER_BOTTLE:-}" || -n "${CROSSOVER_PREFIX:-}" || "${ESO_STRICT_DOCTOR:-0}" == "1" ]]; then
    check_bottle=true
    eso_ensure_bottle_env
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

  if mac="$(eso_mac_addons_dir 2>/dev/null)" && [[ -d "$mac" ]]; then
    log_info "Mac AddOns directory exists: $mac"
  else
    log_warn "Mac AddOns directory missing (ESO_MAC_ADDONS / ~/Documents/.../AddOns)"
    ok=1
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    if eso_minion_mac_app_available; then
      log_info "Minion.app available: ${ESO_MINION_MAC_APP}"
    else
      log_warn "Minion.app missing at ${ESO_MINION_MAC_APP}"
    fi
  fi

  ttc_exe="$(eso_ttc_client_exe)"
  if [[ -f "$ttc_exe" ]]; then
    log_info "TTC Client.exe present: $ttc_exe"
  else
    log_warn "TTC Client.exe missing: $ttc_exe"
  fi

  ttc_helper="$(eso_ttc_mac_helper_app)"
  if [[ -d "$ttc_helper" ]]; then
    log_info "TTC Mac helper app: $ttc_helper"
  else
    log_warn "TTC Mac helper app missing: $ttc_helper (cxmenu --install for bottle)"
  fi

  ttc_lock="$(eso_ttc_lock_path)"
  if [[ -e "$ttc_lock" ]]; then
    log_warn "TTC_Lock present (stale after unclean exit?): $ttc_lock"
  else
    log_info "TTC_Lock absent"
  fi

  if eso_ttc_probe_host_https; then
    :
  else
    log_warn "Host TTC HTTPS probe failed (Mac network/DNS)"
  fi

  eso_ttc_errorlog_summary || true

  if [[ "$check_bottle" == true ]]; then
    if crossover_bottle_exists; then
      log_info "Bottle exists: $(crossover_bottle_root_dir)"
      if bottle="$(crossover_bottle_dir 2>/dev/null)" && [[ -d "$bottle" ]]; then
        log_info "CrossOver drive_c: $bottle"
      fi

      if steam="$(eso_steam_exe_path 2>/dev/null)"; then
        log_info "Steam in bottle: $steam"
      else
        log_warn "Steam not found in bottle — install Steam crosstie via CrossOver"
      fi

      if win="$(eso_win_addons_dir 2>/dev/null)"; then
        if [[ -d "$win" ]]; then
          log_info "Windows AddOns path exists: $win"
        else
          log_warn "Windows AddOns path not found yet (OK before first ESO launch): $win"
        fi
      fi

      if crossover_wineserver_running 2>/dev/null; then
        log_warn "wineserver running for bottle (run: crossover eso quit)"
      else
        log_info "wineserver idle for bottle"
      fi

      if eso_ttc_hosts_present; then
        log_info "TTC hosts pin present (${ESO_TTC_HOSTS_BEGIN})"
      else
        log_warn "TTC hosts pin missing — run: crossover eso fix-ttc-net"
      fi

      if eso_ttc_dotnet48_installed; then
        log_info ".NET Framework 4.8 detected in bottle"
      else
        log_warn ".NET Framework 4.8 not detected — open ties/ttc_client.tie into this bottle"
      fi
    else
      log_error "Bottle not found: ${CROSSOVER_BOTTLE} (create via CrossOver GUI)"
      ok=1
    fi
  else
    log_info "Set CROSSOVER_BOTTLE or ESO_STRICT_DOCTOR=1 to check bottle/Steam"
  fi

  return "$ok"
}
