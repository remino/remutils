#!/usr/bin/env bats

load helpers

@test "shows chain plugin version" {
	_assert_plugin_version chain "$BATS_TEST_DIRNAME/../imgmod" chain -v
}

@test "chains custom imgmod plugins" {
	local output_file="$OUTPUT_DIR/chained.txt"

	printf 'input' > "$INPUT_FILE"
	_write_custom_plugin first '
cp "$1" "$2"
printf "\nfirst" >> "$2"
imgmod_output "$2"
'
	_write_custom_plugin second '
cp "$1" "$2"
printf "\nsecond" >> "$2"
imgmod_output "$2"
'

	run "$BATS_TEST_DIRNAME/../imgmod" chain first -- second -- "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ "$(cat "$output_file")" = "input"$'\n'"first"$'\n'"second" ]
}

@test "chain requires explicit output" {
	printf 'input' > "$INPUT_FILE"
	_write_custom_plugin first 'cp "$1" "$2"; imgmod_output "$2"'
	_write_custom_plugin second 'cp "$1" "$2"; imgmod_output "$2"'

	run "$BATS_TEST_DIRNAME/../imgmod" chain first -- second -- "$INPUT_FILE"

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE: imgmod chain"* ]]
}

@test "chain rejects meta commands" {
	local output_file="$OUTPUT_DIR/chained.txt"

	printf 'input' > "$INPUT_FILE"
	_write_custom_plugin first 'cp "$1" "$2"; imgmod_output "$2"'

	run "$BATS_TEST_DIRNAME/../imgmod" chain completion -- first -- "$INPUT_FILE" "$output_file"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Command cannot be chained: completion"* ]]
}
