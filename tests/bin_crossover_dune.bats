#!/usr/bin/env bats

load test_helper

setup() {
  export CROSSOVER_BOTTLE=""
  export CROSSOVER_PREFIX=""
}

@test "crossover dune paths prints bottle_name" {
  export CROSSOVER_BOTTLE="Dune Awakening"

  run crossover dune paths
  [ "$status" -eq 0 ]
  [[ "$output" == *"bottle_name"* ]]
  [[ "$output" == *"Dune Awakening"* ]]
}

@test "crossover dune paths --json is valid-ish JSON" {
  export CROSSOVER_BOTTLE="Dune Awakening"

  run crossover dune paths --json
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* ]]
  [[ "$output" == *"}" ]]
}

@test "crossover dune doctor fails when bottle configured but missing" {
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  export CROSSOVER_BOTTLE="MissingDuneBottle"

  run crossover dune doctor
  [ "$status" -eq 1 ]
}

@test "crossover help lists dune recipe" {
  run crossover help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dune paths"* ]]
  [[ "$output" == *"dune fix-battleye"* ]]
}

@test "crossover rejects unknown dune command" {
  run crossover dune nosuchcmd
  [ "$status" -eq 2 ]
}

@test "crossover rejects unknown recipe" {
  run crossover nosuchrecipe paths
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown recipe"* ]]
}
