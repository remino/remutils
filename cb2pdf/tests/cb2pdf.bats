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
	[[ "$output" == *"Processing book.cbz"* ]]
	[[ "$output" == *"Created $output_pdf"* ]]
}

@test "cb2pdf keeps spread page wider even with mismatched image DPI metadata" {
	for bin in 7z img2pdf zip magick pdfinfo; do
		command -v "$bin" >/dev/null 2>&1 || skip "Missing required test dependency: $bin"
	done

	TMP_DIR="$(mktemp -d)"
	mkdir -p "$TMP_DIR/pages"

	magick -size 1000x1500 xc:white -units PixelsPerInch -density 300 "$TMP_DIR/pages/001.jpg"
	magick -size 2000x1500 xc:black -units PixelsPerInch -density 600 "$TMP_DIR/pages/002.jpg"

	archive="$TMP_DIR/book.cbz"
	(
		cd "$TMP_DIR/pages"
		zip -q "$archive" ./*.jpg
	)

	output_pdf="$TMP_DIR/book.pdf"
	run "$BATS_TEST_DIRNAME/../cb2pdf" "$archive" "$output_pdf"
	[ "$status" -eq 0 ]

	page1_width="$(pdfinfo -f 1 -l 1 "$output_pdf" | awk '/Page[[:space:]]+1 size:/ {print $4}')"
	page2_width="$(pdfinfo -f 2 -l 2 "$output_pdf" | awk '/Page[[:space:]]+2 size:/ {print $4}')"

	[ "${page1_width%.*}" -lt "${page2_width%.*}" ]
}

@test "cb2pdf excludes hidden and __MACOSX image paths by default" {
	for bin in 7z img2pdf zip magick pdfinfo; do
		command -v "$bin" >/dev/null 2>&1 || skip "Missing required test dependency: $bin"
	done

	TMP_DIR="$(mktemp -d)"
	mkdir -p "$TMP_DIR/pages/.hidden"
	mkdir -p "$TMP_DIR/pages/__MACOSX"

	_make_png "$TMP_DIR/pages/001.png"
	_make_png "$TMP_DIR/pages/.hidden/002.png"
	_make_png "$TMP_DIR/pages/__MACOSX/003.png"

	archive="$TMP_DIR/book.cbz"
	(
		cd "$TMP_DIR/pages"
		zip -q -r "$archive" .
	)

	output_pdf="$TMP_DIR/book.pdf"
	run "$BATS_TEST_DIRNAME/../cb2pdf" "$archive" "$output_pdf"
	[ "$status" -eq 0 ]

	pages="$(pdfinfo "$output_pdf" | awk '/^Pages:/ {print $2}')"
	[ "$pages" -eq 1 ]
}

@test "cb2pdf can disable default excludes with -E" {
	for bin in 7z img2pdf zip magick pdfinfo; do
		command -v "$bin" >/dev/null 2>&1 || skip "Missing required test dependency: $bin"
	done

	TMP_DIR="$(mktemp -d)"
	mkdir -p "$TMP_DIR/pages/.hidden"

	_make_png "$TMP_DIR/pages/001.png"
	_make_png "$TMP_DIR/pages/.hidden/002.png"

	archive="$TMP_DIR/book.cbz"
	(
		cd "$TMP_DIR/pages"
		zip -q -r "$archive" .
	)

	output_pdf="$TMP_DIR/book.pdf"
	run "$BATS_TEST_DIRNAME/../cb2pdf" -E "$archive" "$output_pdf"
	[ "$status" -eq 0 ]

	pages="$(pdfinfo "$output_pdf" | awk '/^Pages:/ {print $2}')"
	[ "$pages" -eq 2 ]
}
