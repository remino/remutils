#!/usr/bin/env bats

load helpers

@test "chains vidmod plugins" {
	local output_file="$OUTPUT_DIR/chained.mp4"
	local first_output

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" chain mp4 -- twitter -- "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[[ "$output" == *"=> $output_file"* ]]
	[ "$(wc -l < "$TOOL_LOG" | tr -d ' ')" = 2 ]
	first_output="$(sed -n '1s/.*<\([^<>]*stage-1\.mp4\)>.*/\1/p' "$TOOL_LOG")"
	[ -n "$first_output" ]
	[[ "$(sed -n '2p' "$TOOL_LOG")" == "ffmpeg <-i> <$first_output>"* ]]
	[[ "$(sed -n '2p' "$TOOL_LOG")" == *"<$output_file>" ]]
}

@test "chain passes stage options" {
	local output_file="$OUTPUT_DIR/chained.mov"
	local expected_filter="crop='if(gte(iw/ih,16/9),ih*16/9,iw)':'if(gte(iw/ih,16/9),ih,iw*9/16)',setsar=1"

	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" chain 169 -f "-y" -- rotate90 -- "$INPUT_FILE" "$output_file"

	[ "$status" -eq 0 ]
	[[ "$(sed -n '1p' "$TOOL_LOG")" == *"<-nostdin> <-y> <-vf> <$expected_filter>"* ]]
	[[ "$(sed -n '2p' "$TOOL_LOG")" == *"<-vf> <transpose=1> <$output_file>" ]]
}

@test "chain requires explicit output" {
	_make_fake_video_tools

	run env PATH="$FAKE_BIN:$PATH" VIDMOD_TOOL_LOG="$TOOL_LOG" "$BATS_TEST_DIRNAME/../vidmod" chain mp4 -- twitter -- "$INPUT_FILE"

	[ "$status" -eq 16 ]
	[[ "$output" == *"USAGE: vidmod chain"* ]]
	[ ! -e "$TOOL_LOG" ]
}
