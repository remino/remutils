#!/usr/bin/env bats

setup() {
	URLSHORTCUT="$BATS_TEST_DIRNAME/../urlshortcut"
	SHORTCUT="$BATS_TEST_TMPDIR/remino.url"
}

@test "urlshortcut writes a shortcut file" {
	run "$URLSHORTCUT" write remino.net "$SHORTCUT"
	[ "$status" -eq 0 ]
	[ "$(cat "$SHORTCUT")" = $'[InternetShortcut]\r\nURL=https://remino.net\r' ]
}

@test "urlshortcut writes a shortcut to standard output by default" {
	run "$URLSHORTCUT" write https://remino.net
	[ "$status" -eq 0 ]
	[ "$output" = $'[InternetShortcut]\r\nURL=https://remino.net\r' ]
}

@test "urlshortcut reads a URL from a shortcut file" {
	printf '[InternetShortcut]\r\nURL=https://remino.net/path\r\n' > "$SHORTCUT"

	run "$URLSHORTCUT" read "$SHORTCUT"
	[ "$status" -eq 0 ]
	[ "$output" = 'https://remino.net/path' ]
}

@test "urlshortcut reads a URL from standard input" {
	run bash -c "'$URLSHORTCUT' write remino.net | '$URLSHORTCUT' read"
	[ "$status" -eq 0 ]
	[ "$output" = 'https://remino.net' ]

	run bash -c "'$URLSHORTCUT' write remino.net | '$URLSHORTCUT' read -"
	[ "$status" -eq 0 ]
	[ "$output" = 'https://remino.net' ]
}

@test "urlshortcut reports help and version" {
	run "$URLSHORTCUT" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *'USAGE: urlshortcut'* ]]

	run "$URLSHORTCUT" --version
	[ "$status" -eq 0 ]
	[ "$output" = 'urlshortcut 0.1.0' ]
}

@test "urlshortcut rejects invalid commands and files" {
	run "$URLSHORTCUT" unknown
	[ "$status" -eq 16 ]
	[[ "$output" == *'unknown command: unknown'* ]]

	run "$URLSHORTCUT" read "$SHORTCUT"
	[ "$status" -eq 17 ]
	[[ "$output" == *'file not found'* ]]
}

@test "urlshortcut rejects URLs with newlines" {
	run "$URLSHORTCUT" write $'https://remino.net\nURL=https://example.com'
	[ "$status" -eq 17 ]
	[[ "$output" == *'URL must not contain a newline'* ]]
}
