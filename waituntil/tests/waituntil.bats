#!/usr/bin/env bats

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

@test "waituntil shows usage with no arguments" {
	run "$BATS_TEST_DIRNAME/../waituntil"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "waituntil shows version with -v" {
	run "$BATS_TEST_DIRNAME/../waituntil" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^waituntil' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "waituntil shows help with -h" {
	run "$BATS_TEST_DIRNAME/../waituntil" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "waituntil handles invalid time format" {
	run "$BATS_TEST_DIRNAME/../waituntil" "invalid-time"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Invalid date format"* ]]
}

@test "waituntil handles past time" {
	if date --version >/dev/null 2>&1; then
		PAST_TIME=$(date -d "-10 seconds" +"%H:%M:%S")
	else
		PAST_TIME=$(date -v-10S +"%H:%M:%S")
	fi

	run "$BATS_TEST_DIRNAME/../waituntil" "$PAST_TIME"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Already past"* ]]
}

@test "waituntil waits until a specific time" {
	if date --version >/dev/null 2>&1; then
		TARGET_TIME=$(date -d "+1 seconds" +"%H:%M:%S")
		start_time=$(date +"%s")
	else
		TARGET_TIME=$(date -v+1S +"%H:%M:%S")
		start_time=$(date +"%s")
	fi

	run "$BATS_TEST_DIRNAME/../waituntil" "$TARGET_TIME"
	end_time=$(date +"%s")

	[ "$status" -eq 0 ]
	elapsed=$((end_time - start_time))
	[ "$elapsed" -eq 1 ]
}

@test "waituntil waits until a specific number of seconds from now" {
	start_time=$(date +"%s")

	run "$BATS_TEST_DIRNAME/../waituntil" 1
	end_time=$(date +"%s")

	[ "$status" -eq 0 ]
	elapsed=$((end_time - start_time))
	[ "$elapsed" -eq 1 ]
}

@test "waituntil adds random delay" {
	start_time=$(date +"%s")

	run "$BATS_TEST_DIRNAME/../waituntil" -r 3 1
	end_time=$(date +"%s")

	[ "$status" -eq 0 ]
	elapsed=$((end_time - start_time))
	[ "$elapsed" -ge 1 ]
	[ "$elapsed" -le 4 ]
}

@test "runat waits until a specific future time" {
	if date --version >/dev/null 2>&1; then
		FUTURE_TIME=$(date -d "+2 seconds" +"%Y-%m-%d %H:%M:%S")
		start_time=$(date +"%s")
	else
		FUTURE_TIME=$(date -v+2S +"%Y-%m-%d %H:%M:%S")
		start_time=$(date +"%s")
	fi

	run "$BATS_TEST_DIRNAME/../runat" "$FUTURE_TIME" echo "Hello, World!"
	end_time=$(date +"%s")

	[ "$status" -eq 0 ]
	[[ "$output" == *"Hello, World!"* ]]
	elapsed=$((end_time - start_time))
	[ "$elapsed" -ge 2 ]
}

@test "runat handles past time" {
	if date --version >/dev/null 2>&1; then
		PAST_TIME=$(date -d "-10 seconds" +"%Y-%m-%d %H:%M:%S")
	else
		PAST_TIME=$(date -v-10S +"%Y-%m-%d %H:%M:%S")
	fi

	run "$BATS_TEST_DIRNAME/../runat" "$PAST_TIME" echo "This should not run"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Already past"* ]]
}
