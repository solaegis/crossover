# shellcheck shell=bash
# Dune: Awakening path resolution inside a CrossOver bottle.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "dune_paths.sh is a library; source it instead of executing." >&2
  exit 1
fi

dune_game_install_relpath() {
  printf '%s\n' "Program Files (x86)/Steam/steamapps/common/DuneAwakening"
}

dune_paths_json_quote() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

dune_drive_c() {
  crossover_bottle_dir 2>/dev/null
}

dune_game_root() {
  local drive_c rel
  if ! drive_c="$(dune_drive_c)"; then
    return 1
  fi
  rel="$(dune_game_install_relpath)"
  printf '%s/%s\n' "$drive_c" "$rel"
}

dune_launcher_exe() {
  local root
  if ! root="$(dune_game_root 2>/dev/null)"; then
    return 1
  fi
  printf '%s/DuneSandbox.exe\n' "$root"
}

dune_be_wrapper_exe() {
  local root
  if ! root="$(dune_game_root 2>/dev/null)"; then
    return 1
  fi
  printf '%s/DuneSandbox/Binaries/Win64/DuneSandbox_BE.exe\n' "$root"
}

dune_shipping_exe() {
  local root
  if ! root="$(dune_game_root 2>/dev/null)"; then
    return 1
  fi
  printf '%s/DuneSandbox/Binaries/Win64/DuneSandbox-Win64-Shipping.exe\n' "$root"
}

dune_battleye_dir() {
  local root
  if ! root="$(dune_game_root 2>/dev/null)"; then
    return 1
  fi
  printf '%s/DuneSandbox/Binaries/Win64/BattlEye\n' "$root"
}

dune_battleye_install_bat() {
  local be_dir
  if ! be_dir="$(dune_battleye_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/Install_BattlEye.bat\n' "$be_dir"
}

dune_battleye_uninstall_bat() {
  local be_dir
  if ! be_dir="$(dune_battleye_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/Uninstall_BattlEye.bat\n' "$be_dir"
}

dune_common_battleye_dir() {
  local drive_c
  if ! drive_c="$(dune_drive_c)"; then
    return 1
  fi
  printf '%s/Program Files (x86)/Common Files/BattlEye\n' "$drive_c"
}

dune_be_service_exe() {
  local common
  if ! common="$(dune_common_battleye_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/BEService.exe\n' "$common"
}

dune_be_service_x64_exe() {
  local be_dir
  if ! be_dir="$(dune_battleye_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/BEService_x64.exe\n' "$be_dir"
}

dune_be_appdata_cache_dir() {
  local drive_c
  if ! drive_c="$(dune_drive_c)"; then
    return 1
  fi
  printf '%s/users/crossover/AppData/Local/BattlEye/dune\n' "$drive_c"
}

dune_cxbottle_conf() {
  local root
  if ! root="$(crossover_bottle_root_dir 2>/dev/null)"; then
    return 1
  fi
  printf '%s/cxbottle.conf\n' "$root"
}

dune_steam_exe_candidates() {
  local drive_c
  if ! drive_c="$(dune_drive_c 2>/dev/null)"; then
    return 1
  fi
  printf '%s/Program Files (x86)/Steam/steam.exe\n' "$drive_c"
  printf '%s/Program Files/Steam/steam.exe\n' "$drive_c"
}

dune_steam_exe_path() {
  local candidate
  while IFS= read -r candidate; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(dune_steam_exe_candidates)
  return 1
}

dune_steam_cx_app() {
  local path
  if path="$(dune_steam_exe_path 2>/dev/null)"; then
    basename "$path"
    return 0
  fi
  printf '%s\n' "steam.exe"
}
