# shellcheck shell=bash
# ESO-specific path resolution. Source from bin/ or tests; do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "eso_paths.sh is a library; source it instead of executing." >&2
  exit 1
fi

eso_default_mac_addons() {
  printf '%s/Documents/Elder Scrolls Online/live/AddOns\n' "${HOME}"
}

eso_mac_addons_dir() {
  local dir="${ESO_MAC_ADDONS:-$(eso_default_mac_addons)}"
  if [[ -d "$dir" ]]; then
    printf '%s\n' "$dir"
    return 0
  fi
  if [[ -n "${ESO_MAC_ADDONS:-}" ]]; then
    printf '%s\n' "$dir"
    return 0
  fi
  return 1
}

eso_win_addons_dir() {
  local prefix win_addons

  if [[ -n "${ESO_WIN_ADDONS:-}" ]]; then
    printf '%s\n' "${ESO_WIN_ADDONS}"
    return 0
  fi

  if ! prefix="$(crossover_bottle_dir 2>/dev/null)"; then
    return 1
  fi

  win_addons="${prefix}/users/crossover/Documents/Elder Scrolls Online/live/AddOns"
  printf '%s\n' "$win_addons"
}

eso_paths_json() {
  local mac addons win bottle
  mac="$(eso_mac_addons_dir 2>/dev/null || true)"
  addons="${mac:-}"
  win="$(eso_win_addons_dir 2>/dev/null || true)"
  bottle="$(crossover_bottle_dir 2>/dev/null || true)"

  printf '{'
  printf '"mac_addons":%s,' "$(eso_paths_json_quote "${addons}")"
  printf '"win_addons":%s,' "$(eso_paths_json_quote "${win}")"
  printf '"crossover_prefix":%s' "$(eso_paths_json_quote "${bottle}")"
  printf '}\n'
}

eso_paths_json_quote() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}
