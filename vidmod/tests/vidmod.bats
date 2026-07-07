#!/usr/bin/env bats

load helpers

@test "shows version" {
	local version
	version="$(_script_version "$BATS_TEST_DIRNAME/../vidmod")"

	run "$BATS_TEST_DIRNAME/../vidmod" -v

	[ "$status" -eq 0 ]
	[ "$output" = "vidmod $version" ]
}

@test "shows help" {
	run "$BATS_TEST_DIRNAME/../vidmod" -h

	[ "$status" -eq 0 ]
	[ "${output:0:7}" = "vidmod " ]
}

@test "runs correctly through a symlink" {
	local link_dir="$OUTPUT_DIR/link-bin"
	local link="$link_dir/vidmod"

	mkdir -p "$link_dir"
	ln -s "$BATS_TEST_DIRNAME/../vidmod" "$link"

	run "$link" completion commands

	[ "$status" -eq 0 ]
	_output_has_line completion
	_output_has_line mp4
	_output_has_line twitter
}

@test "fails for unknown command" {
	run "$BATS_TEST_DIRNAME/../vidmod" unknown

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: unknown"* ]]
	[[ "$output" == *"Run vidmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "completion files are bundled" {
	[ -f "$BATS_TEST_DIRNAME/../completions/bash/vidmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/zsh/_vidmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/fish/vidmod.fish" ]
}

@test "homebrew formula installs shell completions and manpages" {
	grep -q "bash_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "zsh_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "fish_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "man1.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
}
