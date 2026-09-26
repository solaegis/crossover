# shellcheck shell=bash
# CrossOver runtime detection and generic bottle helpers.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "crossover.sh is a library; source it instead of executing." >&2
  exit 1
fi

crossover_support_root() {
  local candidate
  if [[ -n "${CROSSOVER_ROOT:-}" && -d "${CROSSOVER_ROOT}/bin" ]]; then
    printf '%s\n' "${CROSSOVER_ROOT}"
    return 0
  fi
  for candidate in \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver" \
    "${HOME}/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"; do
    if [[ -d "${candidate}/bin" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

crossover_wine_bin() {
  local root
  if ! root="$(crossover_support_root 2>/dev/null)"; then
    return 1
  fi
  if [[ -x "${root}/bin/wine" ]]; then
    printf '%s\n' "${root}/bin/wine"
    return 0
  fi
  return 1
}

crossover_bottles_root() {
  printf '%s/Library/Application Support/CrossOver/Bottles\n' "${HOME}"
}

crossover_bottle_dir() {
  local bottle="${CROSSOVER_BOTTLE:-}"
  local prefix="${CROSSOVER_PREFIX:-}"
  local bottle_root

  if [[ -n "$prefix" ]]; then
    printf '%s\n' "$prefix"
    return 0
  fi

  if [[ -z "$bottle" ]]; then
    return 1
  fi

  bottle_root="$(crossover_bottles_root)/${bottle}"
  if [[ -d "$bottle_root" ]]; then
    printf '%s\n' "${bottle_root}/drive_c"
    return 0
  fi

  printf '%s\n' "${bottle_root}/drive_c"
  return 1
}

crossover_bottle_root_dir() {
  local bottle="${CROSSOVER_BOTTLE:-}"
  local bottle_path

  if [[ -z "$bottle" ]]; then
    return 1
  fi

  bottle_path="$(crossover_bottles_root)/${bottle}"
  if [[ -d "$bottle_path" ]]; then
    printf '%s\n' "$bottle_path"
    return 0
  fi
  printf '%s\n' "$bottle_path"
  return 1
}

crossover_bottle_exists() {
  local bottle_path
  bottle_path="$(crossover_bottle_root_dir 2>/dev/null)" || return 1
  [[ -d "$bottle_path" ]]
}

crossover_open_app() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_warn "CrossOver GUI launch is macOS-only; open CrossOver manually"
    return 0
  fi
  if open -a CrossOver 2>/dev/null; then
    log_info "Opened CrossOver"
    return 0
  fi
  if [[ -d "/Applications/CrossOver.app" ]]; then
    open "/Applications/CrossOver.app"
    log_info "Opened /Applications/CrossOver.app"
    return 0
  fi
  log_warn "Could not open CrossOver automatically"
  return 1
}

# Run CrossOver wine against CROSSOVER_BOTTLE (must be set).
crossover_run_wine() {
  local wine bottle
  if ! wine="$(crossover_wine_bin)"; then
    log_error "CrossOver wine binary not found (install CrossOver or set CROSSOVER_ROOT)"
    return 1
  fi
  bottle="${CROSSOVER_BOTTLE:-}"
  if [[ -z "$bottle" ]]; then
    log_error "CROSSOVER_BOTTLE is not set"
    return 1
  fi
  "$wine" --bottle "$bottle" --no-update "$@"
}

# Graceful Windows session end for the bottle (asks apps to exit, then forces).
crossover_wineboot_end() {
  crossover_run_wine wineboot --end-session --force
}

# Hard-kill the bottle wineserver (stops all Wine processes in the bottle).
# CrossOver wineserver: -k[n] sends signal n. Use plain -k (default SIGINT).
# Do NOT use -k0 — signal 0 is an existence check and does not terminate.
crossover_wineserver_kill() {
  crossover_run_wine --ux-app wineserver -k
}

# SIGTERM then SIGKILL any host processes whose argv still references this bottle.
# Fallback after wineserver -k for orphaned winewrapper hosts (PPID 1).
crossover_bottle_kill_host_procs() {
  local lines pid
  local round

  for round in term kill; do
    lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
    if [[ -z "$lines" ]]; then
      return 0
    fi
    while read -r pid _; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      if [[ "$round" == term ]]; then
        kill -TERM "$pid" 2>/dev/null || true
      else
        kill -KILL "$pid" 2>/dev/null || true
      fi
    done <<<"$lines"
    sleep 1
  done
}

# Force-kill a Windows image name inside the bottle (e.g. eso64.exe). Best-effort.
crossover_taskkill() {
  local image="${1:?image name required (e.g. eso64.exe)}"
  crossover_run_wine taskkill.exe /F /IM "$image" >/dev/null 2>&1 || true
}

# Prefer /bin/ps so interactive shells that alias ps=procs do not break discovery.
crossover_ps_bin() {
  if [[ -x /bin/ps ]]; then
    printf '%s\n' /bin/ps
    return 0
  fi
  command -v ps
}

# Narrow Wine/ESO/Steam images for expensive lsof -p association.
# Exclude steamwebhelper (many CEF children); steam is counted via steam.exe / winewrapper.
crossover_bottle_wine_candidate_re() {
  printf '%s' 'eso64|steam\.exe|Client\.exe|winewrapper|Bethesda\.net_Launcher|TamrielTradeCentre'
}

# True if PID has an open file/dir under bottle_root (PE processes lack WINEPREFIX in ps eww).
crossover_pid_lsof_has_bottle() {
  local pid="${1:?pid required}"
  local bottle_root="${2:?bottle_root required}"
  local out
  command -v lsof >/dev/null 2>&1 || return 1
  # Capture with timeout. Use bash substring match — do not pipe to grep -q under
  # pipefail (early grep close SIGPIPEs the writer and the check looks like failure).
  if command -v perl >/dev/null 2>&1; then
    out="$(perl -e 'alarm 2; exec @ARGV' lsof -p "$pid" 2>/dev/null || true)"
  else
    out="$(lsof -p "$pid" 2>/dev/null || true)"
  fi
  [[ -n "$out" && "$out" == *"$bottle_root"* ]]
}

# PIDs that currently have bottle_root open (fast path for wineserver).
crossover_bottle_lsof_pids() {
  local bottle_root="${1:?bottle_root required}"
  command -v lsof >/dev/null 2>&1 || return 0
  # -F p emits "pPID" lines for processes using this path.
  lsof -F p -- "$bottle_root" 2>/dev/null | sed -n 's/^p//p' | sort -u || true
}

crossover_bottle_emit_ps_line() {
  local pid="${1:?}"
  local cmd="${2:?}"
  printf '%s %s\n' "$pid" "$cmd"
}

# Print bottle-scoped process lines: "PID command".
# Bulk-filters ps output, then associates Windows-argv PE processes via timed lsof -p.
crossover_bottle_process_lines() {
  local bottle_root ps_bin line pid cmd seen_pids="" re lsof_pid all
  if ! bottle_root="$(crossover_bottle_root_dir 2>/dev/null)"; then
    return 1
  fi
  if ! ps_bin="$(crossover_ps_bin)"; then
    return 1
  fi
  re="$(crossover_bottle_wine_candidate_re)"
  all="$("$ps_bin" -axo pid=,command= 2>/dev/null || true)"
  [[ -z "$all" ]] && return 0

  # 1) argv contains Mac bottle path (winewrapper hosts, etc.)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line="${line#"${line%%[![:space:]]*}"}"
    pid="${line%% *}"
    cmd="${line#"$pid"}"
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    case " ${seen_pids} " in
      *" ${pid} "*) continue ;;
    esac
    seen_pids+=" ${pid}"
    crossover_bottle_emit_ps_line "$pid" "$cmd"
  done < <(printf '%s\n' "$all" | grep -F -- "$bottle_root" || true)

  # 2) PIDs holding bottle_root open (lone wineserver)
  while IFS= read -r lsof_pid; do
    [[ "$lsof_pid" =~ ^[0-9]+$ ]] || continue
    case " ${seen_pids} " in
      *" ${lsof_pid} "*) continue ;;
    esac
    line="$(printf '%s\n' "$all" | grep -E "^[[:space:]]*${lsof_pid}[[:space:]]" | head -1 || true)"
    [[ -z "$line" ]] && continue
    line="${line#"${line%%[![:space:]]*}"}"
    cmd="${line#"$lsof_pid"}"
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    seen_pids+=" ${lsof_pid}"
    crossover_bottle_emit_ps_line "$lsof_pid" "$cmd"
  done < <(crossover_bottle_lsof_pids "$bottle_root")

  # 3) Narrow PE/winewrapper candidates: associate via open files under bottle_root.
  # CrossOver PE processes often have empty WINEPREFIX in ps eww; lsof sees drive_c paths.
  # Skip steamwebhelper (argv often embeds steampath=...steam.exe and would false-hit the re).
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line="${line#"${line%%[![:space:]]*}"}"
    pid="${line%% *}"
    cmd="${line#"$pid"}"
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    case " ${seen_pids} " in
      *" ${pid} "*) continue ;;
    esac
    if printf '%s\n' "$cmd" | grep -Fq -- "$bottle_root"; then
      continue
    fi
    if crossover_pid_lsof_has_bottle "$pid" "$bottle_root"; then
      seen_pids+=" ${pid}"
      crossover_bottle_emit_ps_line "$pid" "$cmd"
    fi
  done < <(printf '%s\n' "$all" | grep -iE -- "$re" | grep -vi 'steamwebhelper' || true)
}

crossover_wineserver_running() {
  local lines bottle_root ps_bin pid cmd
  lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
  if [[ -n "$lines" ]]; then
    return 0
  fi
  if ! bottle_root="$(crossover_bottle_root_dir 2>/dev/null)"; then
    return 1
  fi
  if ! ps_bin="$(crossover_ps_bin)"; then
    return 1
  fi
  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    cmd="$("$ps_bin" -p "$pid" -o command= 2>/dev/null || true)"
    if printf '%s\n' "$cmd" | grep -qi -- 'wineserver'; then
      return 0
    fi
  done < <(crossover_bottle_lsof_pids "$bottle_root")
  return 1
}

# Path to the bottle's Windows hosts file (drive_c/windows/system32/drivers/etc/hosts).
crossover_bottle_hosts_path() {
  local drive_c
  if ! drive_c="$(crossover_bottle_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/windows/system32/drivers/etc/hosts\n' "$drive_c"
}

# Idempotent marked block writer for bottle hosts.
# Reads block body from stdin (lines between begin/end marks are managed by this helper).
# Usage: printf '%s\n' "ip host" | crossover_hosts_apply_block "# BEGIN mark" "# END mark"
crossover_hosts_apply_block() {
  local begin="${1:?begin mark required}"
  local end="${2:?end mark required}"
  local hosts_path content tmp stripped
  if ! hosts_path="$(crossover_bottle_hosts_path)"; then
    log_error "Bottle hosts path unavailable (set CROSSOVER_BOTTLE)"
    return 1
  fi
  mkdir -p "$(dirname "$hosts_path")"
  if [[ ! -f "$hosts_path" ]]; then
    printf '# 127.0.0.1 localhost\n' >"$hosts_path"
  fi
  content="$(cat)"
  stripped="$(awk -v b="$begin" -v e="$end" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
  ' "$hosts_path")"
  tmp="$(mktemp)"
  {
    if [[ -n "$stripped" ]]; then
      printf '%s\n' "$stripped"
      printf '\n'
    fi
    printf '%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >"$tmp"
  mv "$tmp" "$hosts_path"
}

crossover_hosts_block_present() {
  local begin="${1:?begin mark required}"
  local hosts_path
  if ! hosts_path="$(crossover_bottle_hosts_path)"; then
    return 1
  fi
  [[ -f "$hosts_path" ]] && grep -qxF "$begin" "$hosts_path"
}
