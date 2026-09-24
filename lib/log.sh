# shellcheck shell=bash
# shellcheck disable=SC2034
# LOG_C_* variables are consumed by sibling libs (e.g. eso_setup.sh).
# Logging helpers. Source from bin/ or tests; do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "log.sh is a library; source it instead of executing." >&2
  exit 1
fi

# Color is on by default. Disable with --no-color or CROSSOVER_NO_COLOR=1 (true/yes).
log_color_enabled() {
  case "${CROSSOVER_NO_COLOR:-}" in
    1 | true | yes) return 1 ;;
  esac
  return 0
}

# Remove --no-color from argv; sets CROSSOVER_NO_COLOR=1 when seen.
# Usage: log_filter_argv outvar "$@"
log_filter_argv() {
  local -n _out=$1
  shift
  _out=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-color)
        export CROSSOVER_NO_COLOR=1
        shift
        ;;
      *)
        _out+=("$1")
        shift
        ;;
    esac
  done
}

log_colors() {
  if log_color_enabled; then
    LOG_C_RESET=$'\033[0m'
    LOG_C_DIM=$'\033[2m'
    LOG_C_RED=$'\033[31m'
    LOG_C_GREEN=$'\033[32m'
    LOG_C_YELLOW=$'\033[33m'
    LOG_C_CYAN=$'\033[36m'
    LOG_C_MAGENTA=$'\033[35m'
    LOG_C_BOLD=$'\033[1m'
    LOG_C_BOLD_RED=$'\033[1;31m'
    LOG_C_BOLD_GREEN=$'\033[1;32m'
    LOG_C_BOLD_YELLOW=$'\033[1;33m'
    LOG_C_BOLD_CYAN=$'\033[1;36m'
    LOG_C_BOLD_MAGENTA=$'\033[1;35m'
  else
    local _name
    for _name in RESET DIM RED GREEN YELLOW CYAN MAGENTA BOLD BOLD_RED BOLD_GREEN BOLD_YELLOW BOLD_CYAN BOLD_MAGENTA; do
      printf -v "LOG_C_${_name}" ''
    done
  fi
}

_log_tag() {
  local label="$1"
  local color_on="$2"
  shift 2
  if log_color_enabled; then
    printf '%b%s:%b %s\n' "$color_on" "$label" "${LOG_C_RESET}" "$*" >&2
  else
    printf '%s: %s\n' "$label" "$*" >&2
  fi
}

log_info() {
  log_colors
  _log_tag info "${LOG_C_BOLD_CYAN}" "$@"
}

log_warn() {
  log_colors
  _log_tag warn "${LOG_C_BOLD_YELLOW}" "$@"
}

log_error() {
  log_colors
  _log_tag error "${LOG_C_BOLD_RED}" "$@"
}

# Dim full line on stderr (uses LOG_C_DIM when color enabled).
log_dim() {
  log_colors
  printf '%b%s%b\n' "${LOG_C_DIM}" "$*" "${LOG_C_RESET}" >&2
}

# Section heading for multi-step GUI instructions (stderr).
log_heading() {
  log_colors
  if log_color_enabled; then
    printf '%b%s%b\n' "${LOG_C_BOLD_MAGENTA}" "$*" "${LOG_C_RESET}" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

# Numbered step label (stderr).
log_step() {
  local n="$1"
  shift
  log_colors
  if log_color_enabled; then
    printf '%b  %s.%b %s\n' "${LOG_C_BOLD}" "$n" "${LOG_C_RESET}" "$*" >&2
  else
    printf '  %s. %s\n' "$n" "$*" >&2
  fi
}

# Y/n prompt; empty or y/yes => 0, n/no => 1.
log_prompt_yn_default_y() {
  local prompt="$1"
  local reply
  log_colors
  if log_color_enabled; then
    printf '%b%b %b[Y/n]%b ' "${LOG_C_BOLD_CYAN}" "$prompt" "${LOG_C_BOLD_GREEN}" "${LOG_C_RESET}" >&2
  else
    printf '%s [Y/n] ' "$prompt" >&2
  fi
  if ! read -r reply </dev/tty; then
    return 1
  fi
  case "${reply,,}" in
    n | no) return 1 ;;
    *) return 0 ;;
  esac
}
