#!/usr/bin/env bats

setup() {
	TOOL="$BATS_TEST_DIRNAME/../timinal"
	TEST_DIR="$(mktemp -d)"
	FAKE_BIN="$TEST_DIR/bin"
	FIGLET_LOG="$TEST_DIR/figlet.log"
	mkdir -p "$FAKE_BIN"
	cat > "$FAKE_BIN/figlet" << 'SCRIPT'
#!/bin/sh
printf '%s\n' "$@" >> "$TIMINAL_FIGLET_LOG"
for argument; do
	value="$argument"
done
printf '[%s]\n' "$value"
SCRIPT
	chmod +x "$FAKE_BIN/figlet"
}

teardown() {
	rm -rf "$TEST_DIR"
}

@test "uses FIGlet's default font when none is requested" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" --format '%H:%M'

	[ "$status" -eq 0 ]
	[ "$output" = "[$(date +%H:%M)]" ]
	[ "$(cat "$FIGLET_LOG")" = "-w
10000
$(date +%H:%M)" ]
}

@test "passes the requested font directly to figlet -f" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" --font custom --format '%H:%M'

	[ "$status" -eq 0 ]
	[ "$output" = "[$(date +%H:%M)]" ]
	[ "$(cat "$FIGLET_LOG")" = "-w
10000
-f
custom
$(date +%H:%M)" ]
}

@test "passes the requested font directory directly to figlet -d" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" --font-dir /fonts -f custom -F '%H:%M'

	[ "$status" -eq 0 ]
	[ "$output" = "[$(date +%H:%M)]" ]
	[ "$(cat "$FIGLET_LOG")" = "-w
10000
-d
/fonts
-f
custom
$(date +%H:%M)" ]
}

@test "accepts short long-form alignment aliases" {
	for option in -l -c -r; do
		run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" "$option" -F x
		[ "$status" -eq 0 ]
	done
}

@test "accepts -s as the short form of --seed" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" -s 7 -F x

	[ "$status" -eq 0 ]
}

@test "accepts -a as the short form of --lolcat" {
	cat > "$FAKE_BIN/lolcat" << 'SCRIPT'
#!/bin/sh
cat
SCRIPT
	chmod +x "$FAKE_BIN/lolcat"

	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" -a -F x

	[ "$status" -eq 0 ]
	[ "$output" = "[x]" ]
}

@test "accepts -L as the short form of --live" {
	run python3 -c '
import importlib.util
import sys

specification = importlib.util.spec_from_file_location("timinal", sys.argv[1])
module = importlib.util.module_from_spec(specification)
specification.loader.exec_module(module)
sys.argv = ["timinal", "-L"]
print(module.parse_args().live)
' "$BATS_TEST_DIRNAME/../timinal.py"

	[ "$status" -eq 0 ]
	[ "$output" = "True" ]
}

@test "uses the literal \\r escape to separate FIGlet blocks" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" --font standard --format 'one\rtwo'

	[ "$status" -eq 0 ]
	[ "$output" = "[one]
[two]" ]
	[ "$(cat "$FIGLET_LOG")" = "-w
10000
-f
standard
one
-w
10000
-f
standard
two" ]
}

@test "uses a left-aligned ISO date and time by default" {
	run env PATH="$FAKE_BIN:$PATH" TIMINAL_FIGLET_LOG="$FIGLET_LOG" "$TOOL" --font standard

	[ "$status" -eq 0 ]
	[ "$output" = "[$(date +%Y-%m-%d)]
[$(date +%H:%M:%S)]" ]
	[ "$(cat "$FIGLET_LOG")" = "-w
10000
-f
standard
$(date +%Y-%m-%d)
-w
10000
-f
standard
$(date +%H:%M:%S)" ]
}

@test "does not provide legacy automatic-font or layout options" {
	for option in --mono --variable --time-only --no-seconds --no-gap; do
		run "$TOOL" --font standard "$option"
		[ "$status" -eq 2 ]
		[[ "$output" == *"unrecognized arguments: $option"* ]]
	done
}
