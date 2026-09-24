#!/usr/bin/env bats

load test_helper

setup() {
  export HOME="${BATS_TEST_TMPDIR}"
}

@test "timemachine exclude script rejects unknown options" {
  run bash "${REPO_ROOT}/scripts/timemachine-exclude-bottles.sh" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "timemachine targets CrossOver Bottles root" {
  local bottles_root="${BATS_TEST_TMPDIR}/Library/Application Support/CrossOver/Bottles"
  mkdir -p "${bottles_root}"

  run crossover_bottles_root
  [ "$status" -eq 0 ]
  [ "$output" = "${bottles_root}" ]
}

@test "crossover_timemachine_is_excluded detects Excluded status" {
  run bash -c '
    tmutil() { echo "[Excluded]  /tmp/test"; }
    export -f tmutil
    source "${REPO_ROOT}/lib/log.sh"
    source "${REPO_ROOT}/lib/timemachine.sh"
    crossover_timemachine_is_excluded /tmp/test
  '
  [ "$status" -eq 0 ]
}
