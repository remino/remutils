#!/usr/bin/env bats

load helpers

@test "shows socshare plugin version" {
	_assert_plugin_version socshare "$BATS_TEST_DIRNAME/../imgmod" socshare -v
}

@test "shows directly-run socshare plugin version" {
	_assert_plugin_version socshare "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" -v
}

@test "shows socshare plugin version with long option" {
	_assert_plugin_version socshare "$BATS_TEST_DIRNAME/../imgmod" socshare --version
}

@test "shows socshare help" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "shows socshare help with help command" {
	run "$BATS_TEST_DIRNAME/../imgmod" help socshare

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "shows direct socshare help with plugin context" {
	run "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE: imgmod socshare"* ]]
}

@test "creates socshare image with automatic filename" {
	_make_input_image

	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "JPEG" ]
}

@test "runs bundled socshare directly" {
	_make_input_image

	run "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "JPEG" ]
}

@test "creates socshare image with requested format" {
	_make_input_image

	run "$BATS_TEST_DIRNAME/../imgmod" socshare -f png "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.png" ]
	[ -f "$output" ]
	[ "$(magick identify -format '%wx%h' "$output")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$output")" = "PNG" ]
}

@test "creates socshare image with explicit output" {
	_make_input_image

	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE" "$EXPLICIT_OUTPUT"

	[ "$status" -eq 0 ]
	[ "$output" = "$EXPLICIT_OUTPUT" ]
	[ -f "$EXPLICIT_OUTPUT" ]
	[ "$(magick identify -format '%wx%h' "$EXPLICIT_OUTPUT")" = "1200x630" ]
	[ "$(magick identify -format '%m' "$EXPLICIT_OUTPUT")" = "WEBP" ]
}

@test "optimizes socshare output when -o is set" {
	_make_input_image
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ -f "$output" ]
	[ "$(cat "$OPTIM_LOG")" = "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "does not optimize socshare output without -o" {
	_make_input_image
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" socshare "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "does not optimize directly-run socshare output" {
	_make_input_image
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../plugins/imgmod-socshare" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ ! -e "$OPTIM_LOG" ]
}

@test "fails when -o is set and image_optim is missing" {
	local safe_path="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	_make_input_image

	run env PATH="$safe_path" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 19 ]
	[[ "$output" == *"Required: image_optim"* ]]
	[ ! -e "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "fails when image_optim fails" {
	_make_input_image
	_make_fake_image_optim 43

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$INPUT_FILE"

	[ "$status" -eq 43 ]
	[ "$output" = "$OUTPUT_DIR/source-pubshare.jpg" ]
	[ "$(cat "$OPTIM_LOG")" = "$OUTPUT_DIR/source-pubshare.jpg" ]
}

@test "does not optimize when plugin fails" {
	_make_fake_image_optim

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_OPTIM_LOG="$OPTIM_LOG" "$BATS_TEST_DIRNAME/../imgmod" -o socshare "$OUTPUT_DIR/missing.png"

	[ "$status" -eq 17 ]
	[[ "$output" == *"No such file"* ]]
	[ ! -e "$OPTIM_LOG" ]
}

@test "fails when input is missing" {
	run "$BATS_TEST_DIRNAME/../imgmod" socshare "$OUTPUT_DIR/missing.png"

	[ "$status" -eq 17 ]
	[[ "$output" == *"No such file"* ]]
}

@test "old pubshare command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" pubshare

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: pubshare"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "old pub-share command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" pub-share

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: pub-share"* ]]
}

@test "old social-share command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" social-share

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: social-share"* ]]
}

@test "old socialshare command name fails" {
	run "$BATS_TEST_DIRNAME/../imgmod" socialshare

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: socialshare"* ]]
}

