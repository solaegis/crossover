#!/usr/bin/env bats

load test_helper

setup() {
  export CROSSOVER_BOTTLE=""
  export CROSSOVER_PREFIX=""
}

@test "dune_bottle_name defaults to Dune: Awakening (Steam)" {
  run dune_bottle_name
  [ "$status" -eq 0 ]
  [ "$output" = "Dune: Awakening (Steam)" ]
}

@test "dune_steam_exe_path finds steam.exe when present" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Dune Awakening"
  mkdir -p "${bottle_root}/drive_c/Program Files (x86)/Steam"
  touch "${bottle_root}/drive_c/Program Files (x86)/Steam/steam.exe"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Dune Awakening"

  run dune_steam_exe_path
  [ "$status" -eq 0 ]
  [[ "$output" == *"steam.exe" ]]
}

@test "dune_be_wrapper_exe resolves when game installed" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Dune Awakening"
  local game="${bottle_root}/drive_c/Program Files (x86)/Steam/steamapps/common/DuneAwakening"
  mkdir -p "${game}/DuneSandbox/Binaries/Win64"
  touch "${game}/DuneSandbox/Binaries/Win64/DuneSandbox_BE.exe"
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Dune Awakening"

  run dune_be_wrapper_exe
  [ "$status" -eq 0 ]
  [[ "$output" == *"DuneSandbox_BE.exe" ]]
}

@test "dune_cxbottle_set_env_var adds ROSETTA_ADVERTISE_AVX" {
  local bottle_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles/Dune Awakening"
  mkdir -p "${bottle_root}"
  cat >"${bottle_root}/cxbottle.conf" <<'EOF'
[EnvironmentVariables]
"WINEMSYNC" = "1"
EOF
  export HOME="${BATS_TEST_TMPDIR}"
  export CROSSOVER_BOTTLE="Dune Awakening"

  run dune_cxbottle_set_env_var "ROSETTA_ADVERTISE_AVX" "1"
  [ "$status" -eq 0 ]
  grep -Fq '"ROSETTA_ADVERTISE_AVX" = "1"' "${bottle_root}/cxbottle.conf"
}

@test "dune_paths_json includes bottle_name and steam_appid" {
  export CROSSOVER_BOTTLE="Dune Awakening"

  run dune_paths_json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"bottle_name":"Dune Awakening"'* ]]
  [[ "$output" == *'"steam_appid":"1172710"'* ]]
}

@test "crossover_tie_path resolves dune_steam tie" {
  run crossover_tie_path dune_steam
  [ "$status" -eq 0 ]
  [[ "$output" == "${REPO_ROOT}/ties/dune_steam.tie" ]]
  [[ -f "$output" ]]
}
