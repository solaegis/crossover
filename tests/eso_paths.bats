#!/usr/bin/env bats

load test_helper

setup() {
  export ESO_MAC_ADDONS=""
  export CROSSOVER_BOTTLE=""
  export CROSSOVER_PREFIX=""
  export ESO_WIN_ADDONS=""
}

@test "eso_mac_addons_dir uses ESO_MAC_ADDONS when set" {
  local tmp
  tmp="$(mktemp -d)"
  export ESO_MAC_ADDONS="${tmp}/addons"
  mkdir -p "${ESO_MAC_ADDONS}"

  run eso_mac_addons_dir
  [ "$status" -eq 0 ]
  [ "$output" = "${ESO_MAC_ADDONS}" ]
}

@test "eso_mac_addons_dir returns 1 when unset and default missing" {
  export HOME="${BATS_TEST_TMPDIR}/empty-home"
  mkdir -p "${HOME}"

  run eso_mac_addons_dir
  [ "$status" -eq 1 ]
}

@test "crossover_bottle_dir resolves from CROSSOVER_PREFIX" {
  local prefix="${BATS_TEST_TMPDIR}/drive_c"
  mkdir -p "${prefix}"
  export CROSSOVER_PREFIX="${prefix}"

  run crossover_bottle_dir
  [ "$status" -eq 0 ]
  [ "$output" = "${prefix}" ]
}

@test "crossover_bottle_dir resolves bottle drive_c layout" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/ESO"
  mkdir -p "${bottle_root}/drive_c"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="ESO"

  run crossover_bottle_dir
  [ "$status" -eq 0 ]
  [[ "$output" == *"/CrossOver/Bottles/ESO/drive_c" ]]
}

@test "eso_win_addons_dir uses ESO_WIN_ADDONS override" {
  local win="${BATS_TEST_TMPDIR}/win/AddOns"
  mkdir -p "${win}"
  export ESO_WIN_ADDONS="${win}"

  run eso_win_addons_dir
  [ "$status" -eq 0 ]
  [ "$output" = "${win}" ]
}

@test "eso_paths_json emits expected keys" {
  local mac="${BATS_TEST_TMPDIR}/mac/AddOns"
  mkdir -p "${mac}"
  export ESO_MAC_ADDONS="${mac}"

  run eso_paths_json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"mac_addons"'* ]]
  [[ "$output" == *'"win_addons"'* ]]
  [[ "$output" == *'"crossover_prefix"'* ]]
}
