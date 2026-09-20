#!/usr/bin/env bats

setup() {
	TEST_ROOT="$(mktemp -d)"
	PREFIX="$TEST_ROOT/prefix"
}

teardown() {
	rm -rf "$TEST_ROOT"
}

@test "every shell-based utility provides an install target" {
	for directory in */; do
		name="${directory%/}"
		[ -f "$name/$name" ] || continue
		case "$name" in
			comprose | litesite | webshot) continue ;;
		esac

		run make -C "$name" -n install
		[ "$status" -eq 0 ]
	done
}

@test "install target stages bundled assets and aliases" {
	run make -C imgmod install "PREFIX=$PREFIX"
	[ "$status" -eq 0 ]
	[ -x "$PREFIX/bin/imgmod" ]
	[ -f "$PREFIX/share/man/man1/imgmod.1" ]
	[ -f "$PREFIX/share/bash-completion/completions/imgmod" ]

	run make -C osc52 install "PREFIX=$PREFIX"
	[ "$status" -eq 0 ]
	[ -L "$PREFIX/bin/osc52copy" ]

	run make -C vid2gif install "PREFIX=$PREFIX"
	[ "$status" -eq 0 ]
	[ -L "$PREFIX/bin/movie2gif" ]
}

@test "installed wrappers resolve their runtime files" {
	run make -C timinal install "PREFIX=$PREFIX"
	[ "$status" -eq 0 ]

	run "$PREFIX/bin/timinal" --format %H:%M
	[ "$status" -eq 0 ]

	run make -C mkprj install "PREFIX=$PREFIX"
	[ "$status" -eq 0 ]

	run "$PREFIX/bin/mkprj" --version
	[ "$status" -eq 0 ]
}

@test "uninstall removes installed files" {
	make -C imgmod install "PREFIX=$PREFIX"
	make -C imgmod uninstall "PREFIX=$PREFIX"

	[ ! -e "$PREFIX/bin/imgmod" ]
	[ ! -e "$PREFIX/libexec/imgmod" ]
}

@test "install supports package staging with DESTDIR" {
	make -C hello install PREFIX=/usr/local "DESTDIR=$TEST_ROOT/stage"
	[ -x "$TEST_ROOT/stage/usr/local/bin/hello" ]

	make -C hello uninstall PREFIX=/usr/local "DESTDIR=$TEST_ROOT/stage"
	[ ! -e "$TEST_ROOT/stage/usr/local/bin/hello" ]
}
