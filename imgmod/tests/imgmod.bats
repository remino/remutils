#!/usr/bin/env bats

load helpers

@test "shows version" {
	local version
	version="$(grep -m1 VERSION "$BATS_TEST_DIRNAME/../imgmod" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"

	run "$BATS_TEST_DIRNAME/../imgmod" -v

	[ "$status" -eq 0 ]
	[ "$output" = "imgmod $version" ]
}

@test "shows help" {
	run "$BATS_TEST_DIRNAME/../imgmod" -h

	[ "$status" -eq 0 ]
	[ "${output:0:7}" = "imgmod " ]
}

@test "shows help with long option" {
	run "$BATS_TEST_DIRNAME/../imgmod" --help

	[ "$status" -eq 0 ]
	[ "${output:0:7}" = "imgmod " ]
}

@test "shows version with long option" {
	local version
	version="$(grep -m1 VERSION "$BATS_TEST_DIRNAME/../imgmod" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"

	run "$BATS_TEST_DIRNAME/../imgmod" --version

	[ "$status" -eq 0 ]
	[ "$output" = "imgmod $version" ]
}

@test "runs correctly through a symlink" {
	local link_dir="$OUTPUT_DIR/link-bin"
	local link="$link_dir/imgmod"

	mkdir -p "$link_dir"
	ln -s "$BATS_TEST_DIRNAME/../imgmod" "$link"

	run "$link" completion commands

	[ "$status" -eq 0 ]
	_output_has_line chain
	_output_has_line completion
	_output_has_line newplugin
	_output_has_line socshare
}

@test "fails for unknown command" {
	run "$BATS_TEST_DIRNAME/../imgmod" unknown

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid command: unknown"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "fails for invalid wrapper option without showing full help" {
	run "$BATS_TEST_DIRNAME/../imgmod" -z

	[ "$status" -eq 16 ]
	[[ "$output" == *"Invalid option: -z"* ]]
	[[ "$output" == *"Run imgmod -h for help."* ]]
	[[ "$output" != *"USAGE:"* ]]
}

@test "completion files are bundled" {
	[ -f "$BATS_TEST_DIRNAME/../completions/bash/imgmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod" ]
	[ -f "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish" ]
}

@test "completion files use plugin command completion API" {
	grep -q "completion bash" "$BATS_TEST_DIRNAME/../completions/bash/imgmod"
	grep -q "completion zsh" "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod"
	grep -q "completion fish" "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/bash/imgmod"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/zsh/_imgmod"
	! grep -q "__complete" "$BATS_TEST_DIRNAME/../completions/fish/imgmod.fish"
}

@test "completion files do not hardcode plugin command names" {
	! grep -R -q "newplugin" "$BATS_TEST_DIRNAME/../completions"
	! grep -R -q "socshare" "$BATS_TEST_DIRNAME/../completions"
}

@test "homebrew formula installs shell completions" {
	grep -q "bash_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "zsh_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
	grep -q "fish_completion.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
}

@test "manpages are bundled" {
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-chain.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-completion.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-newplugin.1" ]
	[ -f "$BATS_TEST_DIRNAME/../man/imgmod-socshare.1" ]
}

@test "manpages document commands" {
	grep -q "^\\.TH IMGMOD " "$BATS_TEST_DIRNAME/../man/imgmod.1"
	grep -q "^\\.TH IMGMOD-CHAIN " "$BATS_TEST_DIRNAME/../man/imgmod-chain.1"
	grep -q "^\\.TH IMGMOD-COMPLETION " "$BATS_TEST_DIRNAME/../man/imgmod-completion.1"
	grep -q "^\\.TH IMGMOD-NEWPLUGIN " "$BATS_TEST_DIRNAME/../man/imgmod-newplugin.1"
	grep -q "^\\.TH IMGMOD-SOCSHARE " "$BATS_TEST_DIRNAME/../man/imgmod-socshare.1"
}

@test "homebrew formula installs manpages" {
	grep -q "man1.install" "$BATS_TEST_DIRNAME/../homebrew.rb.mustache"
}
