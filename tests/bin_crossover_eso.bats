#!/usr/bin/env bats

load test_helper

setup() {
  export ESO_MAC_ADDONS=""
  export CROSSOVER_BOTTLE=""
  export CROSSOVER_PREFIX=""
  export ESO_WIN_ADDONS=""
}

@test "crossover eso paths prints mac addons path" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"

  run crossover eso paths
  [ "$status" -eq 0 ]
  [[ "$output" == *"${mac}"* ]]
}

@test "crossover eso paths --json is valid-ish JSON" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"

  run crossover eso paths --json
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* ]]
  [[ "$output" == *"}" ]]
}

@test "crossover eso doctor succeeds with mac addons only" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"

  run crossover eso doctor
  [ "$status" -eq 0 ]
}

@test "crossover eso doctor fails when bottle configured but missing" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  export CROSSOVER_BOTTLE="MissingBottle"

  run crossover eso doctor
  [ "$status" -eq 1 ]
}

@test "crossover eso paths includes bottle_name" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"

  run crossover eso paths
  [ "$status" -eq 0 ]
  [[ "$output" == *"bottle_name"* ]]
  [[ "$output" == *"The Elder Scrolls Online (Steam)"* ]]
}

@test "crossover help lists eso quit status and ttc" {
  run crossover help
  [ "$status" -eq 0 ]
  [[ "$output" == *"eso paths"* ]]
  [[ "$output" == *"eso status"* ]]
  [[ "$output" == *"eso quit"* ]]
  [[ "$output" == *"eso start"* ]]
  [[ "$output" == *"eso stop"* ]]
  [[ "$output" == *"launch ttc"* ]]
  [[ "$output" == *"launch game"* ]]
  [[ "$output" == *"--no-color"* ]]
  [[ "$output" == *"CROSSOVER_NO_COLOR"* ]]
}

@test "crossover eso status prints bottle fields" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  mkdir -p "${mac}/TamrielTradeCentre/Client" "${bottle_root}/drive_c"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  run crossover eso status
  [ "$status" -eq 0 ]
  [[ "$output" == *"bottle_name"* ]]
  [[ "$output" == *"Elder Scrolls"* ]]
  [[ "$output" == *"ttc_client"* ]]
  [[ "$output" == *"wineserver"* ]]
  [[ "$output" == *"ttc_lock"* ]]
}

@test "crossover eso quit clears TTC_Lock with mocked wine helpers" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  local lock="${mac}/TamrielTradeCentre/Client/TTC_Lock"
  mkdir -p "${mac}/TamrielTradeCentre/Client" "${bottle_root}/drive_c"
  touch "$lock"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  # Avoid touching a real CrossOver bottle: stub wine helpers for this process tree.
  run env CROSSOVER_BOTTLE="Elder Scrolls" ESO_MAC_ADDONS="${mac}" HOME="${BATS_TEST_TMPDIR}" bash -c '
    source "'"${REPO_ROOT}"'/lib/common.sh"
    source "'"${REPO_ROOT}"'/lib/log.sh"
    source "'"${REPO_ROOT}"'/lib/crossover.sh"
    source "'"${REPO_ROOT}"'/lib/eso_paths.sh"
    source "'"${REPO_ROOT}"'/lib/eso_runtime.sh"
    crossover_wine_bin() { printf "/bin/true\n"; }
    crossover_wineboot_end() { return 0; }
    crossover_wineserver_kill() { return 0; }
    crossover_bottle_kill_host_procs() { return 0; }
    crossover_taskkill() { return 0; }
    crossover_bottle_process_lines() { return 0; }
    crossover_wineserver_running() { return 1; }
    eso_awake_off() { return 0; }
    export -f crossover_wine_bin crossover_wineboot_end crossover_wineserver_kill
    export -f crossover_bottle_kill_host_procs crossover_taskkill
    export -f crossover_bottle_process_lines crossover_wineserver_running eso_awake_off
    eso_quit
  '
  [ "$status" -eq 0 ]
  [[ ! -e "$lock" ]]
  [[ "$output" == *"Bottle idle"* ]] || [[ "$output" == *"wineserver"* ]]
}

@test "crossover eso quit --keep-steam rejects unknown flags" {
  run crossover eso quit --bogus
  [ "$status" -eq 2 ]
}

@test "crossover eso start launches steam with -applaunch and ttc detached" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  local open_log="${BATS_TEST_TMPDIR}/open.log"
  local wine_log="${BATS_TEST_TMPDIR}/wine.log"
  mkdir -p "${mac}/TamrielTradeCentre/Client" "${bottle_root}/drive_c/Program Files (x86)/Steam"
  mkdir -p "${BATS_TEST_TMPDIR}/Applications/CrossOver/Tamriel Trade Centre Client.app"
  : >"${mac}/TamrielTradeCentre/Client/Client.exe"
  : >"${bottle_root}/drive_c/Program Files (x86)/Steam/steam.exe"
  : >"$wine_log"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  run env CROSSOVER_BOTTLE="Elder Scrolls" ESO_MAC_ADDONS="${mac}" HOME="${BATS_TEST_TMPDIR}" \
    OPEN_LOG="${open_log}" WINE_LOG="${wine_log}" bash -c '
    source "'"${REPO_ROOT}"'/lib/common.sh"
    source "'"${REPO_ROOT}"'/lib/log.sh"
    source "'"${REPO_ROOT}"'/lib/crossover.sh"
    source "'"${REPO_ROOT}"'/lib/eso_paths.sh"
    source "'"${REPO_ROOT}"'/lib/eso_runtime.sh"
    crossover_wine_bin() { printf "%s\n" "/bin/true"; }
    eso_awake_on() { return 0; }
    open() { printf "%s\n" "$*" >>"${OPEN_LOG}"; }
    # Record wine argv synchronously (eso_start backgrounds nohup … &).
    nohup() { printf "%s\n" "$*" >>"${WINE_LOG}"; }
    disown() { return 0; }
    export -f crossover_wine_bin eso_awake_on open nohup disown
    eso_start
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"eso start"* ]]
  [[ "$output" == *"Steam + ESO + TTC started"* ]] || [[ "$output" == *"-applaunch"* ]]
  [[ "$output" == *"Mac helper"* ]] || [[ "$output" == *"Tamriel Trade Centre"* ]]
  grep -q -- '-applaunch' "$wine_log"
  grep -q -- '306130' "$wine_log"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    [[ -s "$open_log" ]]
  else
    [[ "$output" == *"detached wine"* ]]
  fi
}

@test "crossover eso launch ttc fails when Client.exe missing" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  run crossover eso launch ttc
  [ "$status" -ne 0 ]
  [[ "$output" == *"Client.exe"* ]]
}

@test "crossover help lists fix-ttc-net" {
  run crossover help
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix-ttc-net"* ]]
}

@test "crossover eso fix-ttc-net pins hosts with mocked probes" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  local lock="${mac}/TamrielTradeCentre/Client/TTC_Lock"
  mkdir -p "${mac}/TamrielTradeCentre/Client/ErrorLog" "${bottle_root}/drive_c/windows/system32/drivers/etc"
  printf '# 127.0.0.1 localhost\n' >"${bottle_root}/drive_c/windows/system32/drivers/etc/hosts"
  touch "$lock"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  run env CROSSOVER_BOTTLE="Elder Scrolls" ESO_MAC_ADDONS="${mac}" HOME="${BATS_TEST_TMPDIR}" bash -c '
    source "'"${REPO_ROOT}"'/lib/common.sh"
    source "'"${REPO_ROOT}"'/lib/log.sh"
    source "'"${REPO_ROOT}"'/lib/crossover.sh"
    source "'"${REPO_ROOT}"'/lib/eso_paths.sh"
    source "'"${REPO_ROOT}"'/lib/eso_runtime.sh"
    eso_ttc_probe_host_https() { log_info "Host HTTPS OK: mocked"; return 0; }
    eso_ttc_probe_wine_dns() { log_info "Wine DNS OK: mocked"; return 0; }
    eso_ttc_dotnet48_guidance() { log_info ".NET guidance mocked"; return 0; }
    eso_ttc_menu_guidance() { log_info "menu guidance mocked"; return 0; }
    eso_awake_off() { return 0; }
    export -f eso_ttc_probe_host_https eso_ttc_probe_wine_dns
    export -f eso_ttc_dotnet48_guidance eso_ttc_menu_guidance eso_awake_off
    eso_fix_ttc_net
  '
  [ "$status" -eq 0 ]
  [[ ! -e "$lock" ]]
  local hosts="${bottle_root}/drive_c/windows/system32/drivers/etc/hosts"
  grep -qF '# BEGIN solaegis-ttc' "$hosts"
  grep -qF '104.168.135.156 www.tamrieltradecentre.com' "$hosts"
}
