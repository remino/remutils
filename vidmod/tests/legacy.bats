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

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" rotate90 -o "$output_file" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $output_file" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-vf> <transpose=1> <$output_file>" ]]
}

@test "uses explicit output file and extra ffmpeg options" {
	local output_file="$OUTPUT_DIR/custom-169.mov"
	local expected_filter="crop='if(gte(iw/ih,16/9),ih*16/9,iw)':'if(gte(iw/ih,16/9),ih,iw*9/16)',setsar=1"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" 169 -f "-y -stats" -o "$output_file" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $output_file" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-nostdin> <-y> <-stats> <-vf> <$expected_filter> <$output_file>" ]]
}

@test "fails clearly when output exists in non-interactive mode" {
	local output_file="$OUTPUT_DIR/existing.mov"

	_make_fake_video_tools
	touch "$output_file"

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" 169 -o "$output_file" "$INPUT_FILE"

	[ "$status" -eq 20 ]
	[[ "$output" == *"Output file already exists: $output_file"* ]]
	[[ "$output" == *"Use -y/--overwrite"* ]]
	[ ! -e "$TOOL_LOG" ]
}

@test "overwrites existing output with top-level force flag" {
	local output_file="$OUTPUT_DIR/existing.mov"
	local expected_filter="crop='if(gte(iw/ih,16/9),ih*16/9,iw)':'if(gte(iw/ih,16/9),ih,iw*9/16)',setsar=1"

	_make_fake_video_tools
	touch "$output_file"

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" -y 169 -o "$output_file" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[[ "$(cat "$TOOL_LOG")" == *"<-nostdin> <-y> <-vf> <$expected_filter> <$output_file>" ]]
}

@test "prompts before overwriting on a tty by default" {
	local output_file="$OUTPUT_DIR/existing.mov"

	command -v script > /dev/null 2>&1 || skip "script is required"
	script -q /dev/null /bin/bash -lc 'test -w /dev/tty && test -r /dev/tty' > /dev/null 2>&1 || skip "script TTY access is unavailable"

	_make_fake_video_tools
	touch "$output_file"

	run env FAKE_BIN="$FAKE_BIN" INPUT_FILE="$INPUT_FILE" OUTPUT_FILE="$output_file" SCRIPT_PATH="$BATS_TEST_DIRNAME/../vidmod" TOOL_LOG="$TOOL_LOG" bash -lc \
		'printf "y\n" | env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" script -q /dev/null "$SCRIPT_PATH" 169 -o "$OUTPUT_FILE" "$INPUT_FILE"'

	[ "$status" -eq 0 ]
	[[ "$output" == *"Overwrite existing file? [y/N] $output_file"* ]]
	[[ "$(cat "$TOOL_LOG")" == *"<-y>"* ]]
}

@test "rejects positional output file" {
	local output_file="$OUTPUT_DIR/final.mp4"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" rotate90 "$INPUT_FILE" "$output_file"

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE: vidmod rotate90"* ]]
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

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE: vidmod mp4"* ]]
	[ ! -e "$TOOL_LOG" ]
}

@test "runs non-ffmpeg legacy tools" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" butter "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$(cat "$TOOL_LOG")" = "butterflow <$INPUT_FILE> <-r> <120> <-audio> <--levels> <6> <-o> <$OUTPUT_DIR/source-butter.mov>" ]
}

@test "fits video into 1080p frame" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" fit1080 "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $OUTPUT_DIR/source-fit1080.mov" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-vf> <scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2> <-c:a> <copy> <$OUTPUT_DIR/source-fit1080.mov>" ]]
}

@test "fits video into 1080p frame with explicit output" {
	local output_file="$OUTPUT_DIR/framed.mov"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" fit1080 -o "$output_file" "$INPUT_FILE"

	[ "$status" -eq 0 ]
	[ "$output" = "<= $INPUT_FILE"$'\n'"=> $output_file" ]
	[[ "$(cat "$TOOL_LOG")" == *"<-vf> <scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2> <-c:a> <copy> <$output_file>" ]]
}
