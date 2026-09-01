#!/usr/bin/env bats

@test "shows wrapper version" {
	run "$BATS_TEST_DIRNAME/../addwatermark" --version

	[ "$status" -eq 0 ]
	[ "$output" = "addwatermark 2.1.0" ]
}

@test "translates legacy arguments to imgmod watermark" {
	local fake_bin
	local log

	fake_bin="$(mktemp -d)"
	log="$fake_bin/log"

	cat > "$fake_bin/imgmod" << 'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" > "$ADDMARK_LOG"
SCRIPT
	chmod a+x "$fake_bin/imgmod"

	run env ADDMARK_LOG="$log" IMGMOD_BIN="$fake_bin/imgmod" "$BATS_TEST_DIRNAME/../addwatermark" -a 0.8 -s 20 logo.png input.jpg output.png

	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "watermark -a 0.8 -s 20 -w logo.png -o output.png input.jpg" ]
	rm -rf "$fake_bin"
}
