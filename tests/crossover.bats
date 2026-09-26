#!/usr/bin/env bats

load test_helper

setup() {
  export CROSSOVER_BOTTLE=""
  export CROSSOVER_PREFIX=""
  export ESO_WIN_ADDONS=""
}

@test "eso_bottle_name defaults to The Elder Scrolls Online (Steam)" {
  run eso_bottle_name
  [ "$status" -eq 0 ]
  [ "$output" = "The Elder Scrolls Online (Steam)" ]
}

@test "eso_minion_mac_app_available when bundle has jar and lib" {
  local app_root="${BATS_TEST_TMPDIR}/Minion.app/Contents/Resources"
  mkdir -p "${app_root}/lib"
  touch "${app_root}/Minion-jfx.jar"
  touch "${app_root}/lib/dep.jar"
  export ESO_MINION_MAC_APP="${BATS_TEST_TMPDIR}/Minion.app"

  run eso_minion_mac_app_available
  [ "$status" -eq 0 ]
}

@test "eso_setup_check_minion_mac_app succeeds with valid Minion.app" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    skip "macOS only"
  fi
  local app_root="${BATS_TEST_TMPDIR}/Minion.app/Contents/Resources"
  mkdir -p "${app_root}/lib"
  touch "${app_root}/Minion-jfx.jar"
  touch "${app_root}/lib/dep.jar"
  export ESO_MINION_MAC_APP="${BATS_TEST_TMPDIR}/Minion.app"
  export HOME="${BATS_TEST_TMPDIR}"
  mkdir -p "${HOME}/Documents/Elder Scrolls Online/live/AddOns"

  run eso_setup_check_minion_mac_app
  [ "$status" -eq 0 ]
  [[ "$output" == *"Minion.app ready"* ]]
}

@test "eso_steam_exe_path finds steam.exe when present" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  mkdir -p "${bottle_root}/drive_c/Program Files (x86)/Steam"
  touch "${bottle_root}/drive_c/Program Files (x86)/Steam/steam.exe"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  run eso_steam_exe_path
  [ "$status" -eq 0 ]
  [[ "$output" == *"steam.exe" ]]
}

@test "eso_setup_wait_for_bottle_gui returns immediately when bottle exists" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  mkdir -p "${bottle_root}"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"
  eso_ensure_bottle_env

  run eso_setup_wait_for_bottle_gui
  [ "$status" -eq 0 ]
}

@test "eso_setup_wait_for_bottle_gui skips without tty" {
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"
  eso_ensure_bottle_env

  run eso_setup_wait_for_bottle_gui
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not a terminal"* ]]
}

@test "log_color_enabled is on by default" {
  unset CROSSOVER_NO_COLOR
  run log_color_enabled
  [ "$status" -eq 0 ]
}

@test "log_color_enabled off when CROSSOVER_NO_COLOR=1" {
  export CROSSOVER_NO_COLOR=1
  run log_color_enabled
  [ "$status" -eq 1 ]
}

@test "log_info emits ANSI color by default" {
  unset CROSSOVER_NO_COLOR
  run bash -c 'source "${REPO_ROOT}/lib/log.sh"; log_info colored' 2>&1
  [[ "$output" == *$'\033['* ]]
}

@test "log_info plain when CROSSOVER_NO_COLOR=1" {
  run env CROSSOVER_NO_COLOR=1 bash -c 'source "${REPO_ROOT}/lib/log.sh"; log_info plain' 2>&1
  [[ "$output" == "info: plain" ]]
  [[ ! "$output" == *$'\033['* ]]
}

@test "log_filter_argv strips --no-color and sets CROSSOVER_NO_COLOR" {
  unset CROSSOVER_NO_COLOR
  local -a rest=()
  log_filter_argv rest --no-color --skip-launchers
  [ "${#rest[@]}" -eq 1 ]
  [ "${rest[0]}" = "--skip-launchers" ]
  [ "${CROSSOVER_NO_COLOR:-}" = "1" ]
}

@test "eso_setup_wait_for_bottle_gui skips with ESO_SKIP_GUI_WAIT" {
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"
  export ESO_SKIP_GUI_WAIT=1
  eso_ensure_bottle_env

  run eso_setup_wait_for_bottle_gui
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESO_SKIP_GUI_WAIT"* ]]
}

@test "eso_doctor strict fails when bottle missing" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  export CROSSOVER_BOTTLE="MissingBottle"
  export ESO_STRICT_DOCTOR=1

  run eso_doctor
  [ "$status" -eq 1 ]
}

@test "crossover_tie_path resolves tracked eso_standalone tie" {
  run crossover_tie_path eso_standalone
  [ "$status" -eq 0 ]
  [[ "$output" == "${REPO_ROOT}/ties/eso_standalone.tie" ]]
  [[ -f "$output" ]]
}

@test "crossover_tie_path accepts name with .tie suffix" {
  run crossover_tie_path eso_standalone.tie
  [ "$status" -eq 0 ]
  [[ "$output" == "${REPO_ROOT}/ties/eso_standalone.tie" ]]
}

@test "crossover_tie_path fails for unknown tie" {
  run crossover_tie_path does_not_exist
  [ "$status" -eq 1 ]
}

@test "crossover_tie_path resolves tracked ttc_client tie" {
  run crossover_tie_path ttc_client
  [ "$status" -eq 0 ]
  [[ "$output" == "${REPO_ROOT}/ties/ttc_client.tie" ]]
  [[ -f "$output" ]]
}

@test "crossover_tie_path resolves tracked eso_steam tie" {
  run crossover_tie_path eso_steam
  [ "$status" -eq 0 ]
  [[ "$output" == "${REPO_ROOT}/ties/eso_steam.tie" ]]
  [[ -f "$output" ]]
}

@test "crossover_hosts_apply_block is idempotent" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  mkdir -p "${bottle_root}/drive_c/windows/system32/drivers/etc"
  printf '# 127.0.0.1 localhost\n' >"${bottle_root}/drive_c/windows/system32/drivers/etc/hosts"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  printf '1.2.3.4 example.test\n' | crossover_hosts_apply_block "# BEGIN solaegis-ttc" "# END solaegis-ttc"
  printf '1.2.3.4 example.test\n' | crossover_hosts_apply_block "# BEGIN solaegis-ttc" "# END solaegis-ttc"

  local hosts="${bottle_root}/drive_c/windows/system32/drivers/etc/hosts"
  local begin_count
  begin_count="$(grep -cF '# BEGIN solaegis-ttc' "$hosts")"
  [ "$begin_count" -eq 1 ]
  grep -qF '1.2.3.4 example.test' "$hosts"
  run crossover_hosts_block_present "# BEGIN solaegis-ttc"
  [ "$status" -eq 0 ]
}

@test "crossover_wineserver_kill uses wineserver -k not -k0" {
  run bash -c '
    source "'"${REPO_ROOT}"'/lib/common.sh"
    source "'"${REPO_ROOT}"'/lib/log.sh"
    source "'"${REPO_ROOT}"'/lib/crossover.sh"
    crossover_run_wine() { printf "%s\n" "$*"; }
    export -f crossover_run_wine
    crossover_wineserver_kill
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"--ux-app wineserver -k" ]]
  [[ "$output" != *"-k0"* ]]
}

@test "crossover_bottle_process_lines includes lsof-scoped Windows-path eso64" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Elder Scrolls"
  local mock_ps="${BATS_TEST_TMPDIR}/bin/mock_ps"
  local mock_lsof="${BATS_TEST_TMPDIR}/bin/lsof"
  mkdir -p "${bottle_root}/drive_c" "${BATS_TEST_TMPDIR}/bin"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Elder Scrolls"

  cat >"$mock_ps" <<EOF
#!/usr/bin/env bash
printf '%s\n' ' 4242 C:\\Program Files\\Zenimax\\eso64.exe Language.2=en'
printf '%s\n' ' 4243 C:\\Program Files\\Zenimax\\eso64.exe other-bottle'
printf '%s\n' ' 1000 /Applications/CrossOver.app/winewrapper.exe --run -- ${bottle_root}/drive_c/Steam/steam.exe'
EOF
  chmod +x "$mock_ps"

  cat >"$mock_lsof" <<EOF
#!/usr/bin/env bash
# Support: lsof -F p -- PATH  and  lsof -p PID
if [[ "\$1" == "-F" ]]; then
  exit 0
fi
pid=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -p) pid="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "\$pid" == "4242" ]]; then
  printf 'eso64.exe %s %s/drive_c/game/eso64.exe\n' "\$pid" '${bottle_root}'
elif [[ "\$pid" == "4243" ]]; then
  printf 'eso64.exe %s /other/bottle/drive_c/game/eso64.exe\n' "\$pid"
fi
exit 0
EOF
  chmod +x "$mock_lsof"

  run env HOME="${BATS_TEST_TMPDIR}" CROSSOVER_BOTTLE="Elder Scrolls" \
    MOCK_PS="$mock_ps" PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" bash -c '
    source "'"${REPO_ROOT}"'/lib/common.sh"
    source "'"${REPO_ROOT}"'/lib/log.sh"
    source "'"${REPO_ROOT}"'/lib/crossover.sh"
    crossover_ps_bin() { printf "%s\n" "${MOCK_PS}"; }
    export -f crossover_ps_bin
    crossover_bottle_process_lines
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"4242"* ]]
  [[ "$output" == *"eso64"* ]]
  [[ "$output" == *"1000"* ]]
  [[ "$output" != *"4243"* ]]
}
