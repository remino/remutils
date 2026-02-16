#!/usr/bin/env bats

teardown() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

_make_png() {
	local out_file="$1"
	magick -size 100x100 xc:white "$out_file"
}

@test "cb2pdf shows usage with no arguments" {
	run "$BATS_TEST_DIRNAME/../cb2pdf"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE:"* ]]
}

@test "cb2pdf shows version with -v" {
	run "$BATS_TEST_DIRNAME/../cb2pdf" -v
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^cb2pdf' '[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "cb2pdf fails with missing input file" {
	run "$BATS_TEST_DIRNAME/../cb2pdf" /non/existent/file.cbz
	[ "$status" -eq 17 ]
	[[ "$output" == *"FATAL: Missing or not a file:"* ]]
}

@test "cb2pdf fails with unsupported extension" {
	TMP_DIR="$(mktemp -d)"
	touch "$TMP_DIR/input.txt"

	run "$BATS_TEST_DIRNAME/../cb2pdf" "$TMP_DIR/input.txt"
	[ "$status" -eq 19 ]
	[[ "$output" == *"FATAL: Unsupported input extension:"* ]]
}

@test "cb2pdf converts cbz to pdf" {
	for bin in 7z img2pdf zip magick; do
		command -v "$bin" >/dev/null 2>&1 || skip "Missing required test dependency: $bin"
	done

	TMP_DIR="$(mktemp -d)"
	mkdir -p "$TMP_DIR/pages"
	_make_png "$TMP_DIR/pages/001.png"
	_make_png "$TMP_DIR/pages/002.png"

	archive="$TMP_DIR/book.cbz"
	(
		cd "$TMP_DIR/pages"
		zip -q "$archive" ./*.png
	)

	output_pdf="$TMP_DIR/book.pdf"
	run "$BATS_TEST_DIRNAME/../cb2pdf" "$archive" "$output_pdf"

	[ "$status" -eq 0 ]
	[ -f "$output_pdf" ]
	[ "$(wc -c <"$output_pdf")" -gt 0 ]
	[[ "$output" == *"Created $output_pdf"* ]]
}
