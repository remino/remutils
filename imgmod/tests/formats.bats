#!/usr/bin/env bats

load helpers

@test "png8 converts to automatic output path" {
	_make_fake_imgmod_tool magick
	touch "$INPUT_FILE"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../imgmod" png8 "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-png8.png" ]
	[ -f "$output" ]
	[ "$(cat "$TOOL_LOG")" = "magick <$INPUT_FILE> <PNG8:$OUTPUT_DIR/source-png8.png>" ]
}

@test "scale4x scales with point filter" {
	local output_file="$OUTPUT_DIR/scaled.png"

	_make_fake_imgmod_tool magick
	touch "$INPUT_FILE"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../imgmod" scale4x "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ -f "$output_file" ]
	[ "$(cat "$TOOL_LOG")" = "magick <$INPUT_FILE> <-filter> <point> <-resize> <400%> <$output_file>" ]
}

@test "vidframe extracts first frame by default" {
	local input_file="$OUTPUT_DIR/export.mov"

	_make_fake_imgmod_tool ffmpeg
	touch "$input_file"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../imgmod" vidframe "$input_file"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/export-frame.png" ]
	[ -f "$output" ]
	[ "$(cat "$TOOL_LOG")" = "ffmpeg <-i> <$input_file> <-frames:v> <1> <$OUTPUT_DIR/export-frame.png>" ]
}

@test "vidframe extracts a timestamp" {
	local input_file="$OUTPUT_DIR/export.mov"
	local output_file="$OUTPUT_DIR/still.png"

	_make_fake_imgmod_tool ffmpeg
	touch "$input_file"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../imgmod" vidframe -t 00:00:02.500 "$input_file" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ -f "$output_file" ]
	[ "$(cat "$TOOL_LOG")" = "ffmpeg <-ss> <00:00:02.500> <-i> <$input_file> <-frames:v> <1> <$output_file>" ]
}

@test "vidframe extracts a frame number" {
	local input_file="$OUTPUT_DIR/export.mov"
	local output_file="$OUTPUT_DIR/still.png"

	_make_fake_imgmod_tool ffmpeg
	touch "$input_file"

	run env PATH="$FAKE_BIN:$PATH" IMGMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../imgmod" vidframe -f 12 "$input_file" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "$output_file" ]
	[ -f "$output_file" ]
	[ "$(cat "$TOOL_LOG")" = "ffmpeg <-i> <$input_file> <-vf> <select=eq(n\\,12)> <-frames:v> <1> <-vsync> <0> <$output_file>" ]
}

@test "vidframe rejects frame and timestamp together" {
	local input_file="$OUTPUT_DIR/export.mov"

	touch "$input_file"

	run "$BATS_TEST_DIRNAME/../imgmod" vidframe -f 1 -t 1 "$input_file"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Use either -f or -t, not both."* ]]
}
