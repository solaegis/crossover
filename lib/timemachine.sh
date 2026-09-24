# shellcheck shell=bash
# Time Machine exclusion helpers for CrossOver bottle paths (macOS).

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "timemachine.sh is a library; source it instead of executing." >&2
  exit 1
fi

crossover_timemachine_is_excluded() {
  local path="$1"
  tmutil isexcluded "$path" 2>/dev/null | grep -Fq '[Excluded]'
}

crossover_timemachine_exclude() {
  local path="$1"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "Time Machine exclusions are macOS-only"
    return 1
  fi
  if ! command -v tmutil >/dev/null 2>&1; then
    log_error "tmutil not found"
    return 1
  fi

  if crossover_timemachine_is_excluded "$path"; then
    log_info "Already excluded from Time Machine: $path"
    return 0
  fi

  # Non-persistent exclusion works without root; -p requires administrator privileges.
  if ! tmutil addexclusion "$path"; then
    log_error "tmutil addexclusion failed for: $path"
    log_error "You can also exclude this folder in System Settings → General → Time Machine → Options."
    return 1
  fi
  if ! crossover_timemachine_is_excluded "$path"; then
    log_warn "tmutil reported success but path is not excluded: $path"
    return 1
  fi
  log_info "Excluded from Time Machine: $path"

  if [[ "${CROSSOVER_TIME_MACHINE_PERSISTENT:-}" == 1 ]]; then
    if tmutil addexclusion -p "$path" 2>/dev/null; then
      log_info "Persistent exclusion applied (-p)."
    else
      log_warn "Persistent exclusion (-p) requires administrator privileges."
      log_warn "Run: sudo tmutil addexclusion -p $(printf '%q' "$path")"
    fi
  fi
}

crossover_timemachine_print_status() {
  local path="$1"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "Time Machine status is macOS-only"
    return 1
  fi
  if ! command -v tmutil >/dev/null 2>&1; then
    log_error "tmutil not found"
    return 1
  fi

  printf '%s\n' "$path"
  tmutil isexcluded "$path" 2>/dev/null || true
  if crossover_timemachine_is_excluded "$path"; then
    log_info "Time Machine will not back up this path."
    return 0
  fi
  log_warn "Path is included in Time Machine backups."
  return 1
}
