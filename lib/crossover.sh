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
crossover_wineserver_kill() {
  crossover_run_wine --ux-app wineserver -k0
}

# Force-kill a Windows image name inside the bottle (e.g. eso64.exe). Best-effort.
crossover_taskkill() {
  local image="${1:?image name required (e.g. eso64.exe)}"
  crossover_run_wine taskkill.exe /F /IM "$image" >/dev/null 2>&1 || true
}

# Print process command lines that reference this bottle's path (macOS/Linux ps).
crossover_bottle_process_lines() {
  local bottle_root needle
  if ! bottle_root="$(crossover_bottle_root_dir 2>/dev/null)"; then
    return 1
  fi
  needle="$bottle_root"
  if ! command -v ps >/dev/null 2>&1; then
    return 1
  fi
  # shellcheck disable=SC2009
  ps -axo pid=,command= 2>/dev/null | grep -F "$needle" | grep -v grep || true
}

crossover_wineserver_running() {
  local lines
  lines="$(crossover_bottle_process_lines 2>/dev/null || true)"
  if [[ -z "$lines" ]]; then
    return 1
  fi
  printf '%s\n' "$lines" | grep -qi 'wineserver' && return 0
  # Any bottle-scoped wine process implies the server is up.
  return 0
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
