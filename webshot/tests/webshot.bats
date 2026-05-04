#!/usr/bin/env bats

@test "npm test passes" {
  run npm test --prefix "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}
