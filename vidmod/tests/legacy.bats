#!/usr/bin/env bats

load helpers

@test "runs mp4 plugin on one input" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" mp4 "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $OUTPUT_DIR/source.mp4" ]
	[ "$(cat "$TOOL_LOG")" = "ffmpeg <-i> <$INPUT_FILE> <-hide_banner> <-loglevel> <panic> <-nostdin> <$OUTPUT_DIR/source.mp4>" ]
}

@test "uses explicit output file" {
	local output_file="$OUTPUT_DIR/final.mp4"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" rotate90 "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $output_file" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-vf> <transpose=1> <$output_file>" ]]
}

@test "uses explicit output file and extra ffmpeg options" {
	local output_file="$OUTPUT_DIR/custom-169.mov"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" 169 -f "-y -stats" "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $output_file" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-nostdin> <-y> <-stats> <-vf> <setdar=16/9> <$output_file>" ]]
}

@test "does not accept output file option" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" 169 -o "$OUTPUT_DIR/out.mov" "$INPUT_FILE"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid option: -o"* ]]
	[ ! -e "$TOOL_LOG" ]
}

@test "does not accept output directory option" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" 169 -d "$OUTPUT_DIR" "$INPUT_FILE"

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid option: -d"* ]]
	[ ! -e "$TOOL_LOG" ]
}

@test "does not treat old vidmod chain syntax as a chain" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" mp4 twitter "$INPUT_FILE"

	[ "$status" -eq 17 ]
	[[ "$output" == *"File not found: twitter"* ]]
	[ ! -e "$TOOL_LOG" ]
}

@test "runs non-ffmpeg legacy tools" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" butter "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$(cat "$TOOL_LOG")" = "butterflow <$INPUT_FILE> <-r> <120> <-audio> <--levels> <6> <-o> <$OUTPUT_DIR/source-butter.mov>" ]
}
