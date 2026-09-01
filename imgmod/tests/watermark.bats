#!/usr/bin/env bats

load helpers

@test "shows watermark plugin version" {
	run "$BATS_TEST_DIRNAME/../imgmod" watermark -v

	[ "$status" -eq 0 ]
	[ "$output" = "imgmod watermark 2.1.0" ]
}

@test "shows watermark help" {
	run "$BATS_TEST_DIRNAME/../imgmod" watermark -h

	[ "$status" -eq 0 ]
	[[ "$output" == *"-w <watermark>"* ]]
}

@test "creates a watermarked image" {
	local watermark="$OUTPUT_DIR/watermark.png"

	_make_input_image
	magick -size 100x50 xc:white "$watermark"

	run "$BATS_TEST_DIRNAME/../imgmod" watermark -w "$watermark" -o "$EXPLICIT_OUTPUT" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$EXPLICIT_OUTPUT" ]
	[ -f "$EXPLICIT_OUTPUT" ]
}

@test "uses a generated output path" {
	local watermark="$OUTPUT_DIR/watermark.png"

	_make_input_image
	magick -size 100x50 xc:white "$watermark"

	run "$BATS_TEST_DIRNAME/../imgmod" watermark -w "$watermark" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "$OUTPUT_DIR/source-watermarked.png" ]
	[ -f "$output" ]
}
