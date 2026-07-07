#!/usr/bin/env bash
# Shared helpers for imgmod and its plugins.

E_ARGS=16
E_NO_FILE=17
E_MISSING_APP=19

IMGMOD_PLUGIN_PREFIX="${IMGMOD_PLUGIN_PREFIX:-imgmod-}"

APP_NAME="${IMGMOD_APP_NAME:-imgmod}"
PLUGIN_NAME="${IMGMOD_PLUGIN_NAME:-$(basename "$0")}"
[[ "$PLUGIN_NAME" == "$IMGMOD_PLUGIN_PREFIX"* ]] && PLUGIN_NAME="${PLUGIN_NAME#"$IMGMOD_PLUGIN_PREFIX"}"
PLUGIN_PREFIX="$(echo "$PLUGIN_NAME" | sed 's/[^A-Za-z0-9_]/_/g')"
[[ "$PLUGIN_PREFIX" =~ ^[0-9] ]] && PLUGIN_PREFIX="_$PLUGIN_PREFIX"
USAGE_NAME="$APP_NAME $PLUGIN_NAME"

_echo() {
	echo "$@"
}

_error() {
	_echo "$@" >&2
}

_exit() {
	local status=$?
	exit "${1:-$status}"
}

_fatal() {
	local exit_code=$1
	shift
	_error "$@"
	exit "$exit_code"
}

imgmod_plugin_run() {
	local start_hook="${PLUGIN_PREFIX}_start"
	local help_hook="${PLUGIN_PREFIX}_help"

	trap _exit INT TERM

	if declare -F "$start_hook" > /dev/null 2>&1; then
		"$start_hook" "$@"
		return
	fi

	if declare -F "$help_hook" > /dev/null 2>&1; then
		"$help_hook"
	fi

	return $E_ARGS
}

imgmod_output() {
	local output=$1

	_echo "$output"

	if [ -n "${IMGMOD_OUTPUTS_FILE:-}" ]; then
		_echo "$output" >> "$IMGMOD_OUTPUTS_FILE"
	fi
}

imgmod_plugin_dirs() {
	local data_home
	local data_dirs
	local dir

	data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
	data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

	_echo "$data_home/imgmod/plugins"

	IFS=: read -ra dirs <<< "$data_dirs"
	for dir in "${dirs[@]}"; do
		[ -z "$dir" ] && continue
		_echo "$dir/imgmod/plugins"
	done

	if [ -n "${IMGMOD_PLUGIN_DIR:-}" ]; then
		_echo "$IMGMOD_PLUGIN_DIR"
	fi
}

imgmod_find_plugin() {
	local command_name=$1
	local dir
	local plugin

	while IFS= read -r dir; do
		plugin="$dir/$IMGMOD_PLUGIN_PREFIX$command_name"
		if [ -f "$plugin" ] && [ -x "$plugin" ]; then
			_echo "$plugin"
			return
		fi
	done < <(imgmod_plugin_dirs)
}

imgmod_list_commands() {
	local seen=' help version '
	local dir
	local plugin
	local command_name

	_echo help
	_echo version

	while IFS= read -r dir; do
		[ -d "$dir" ] || continue

		for plugin in "$dir"/*; do
			[ -e "$plugin" ] || continue
			[ -f "$plugin" ] && [ -x "$plugin" ] || continue

			command_name="$(basename "$plugin")"
			[[ "$command_name" == "$IMGMOD_PLUGIN_PREFIX"* ]] || continue
			command_name="${command_name#"$IMGMOD_PLUGIN_PREFIX"}"

			case " $seen " in
				*" $command_name "*) continue ;;
			esac

			seen="$seen$command_name "
			_echo "$command_name"
		done
	done < <(imgmod_plugin_dirs)
}

_imgmod_output() {
	imgmod_output "$@"
}

_imgmod_outputs_begin() {
	local outputs_file=$1

	export IMGMOD_OUTPUTS_FILE="$outputs_file"
}

_imgmod_outputs_end() {
	unset IMGMOD_OUTPUTS_FILE
}

_imgmod_optimize_outputs() {
	local outputs_file=$1
	local output
	local status

	while IFS= read -r output; do
		[ -f "$output" ] || continue

		image_optim "$output"
		status=$?

		if [ "$status" -ne 0 ]; then
			return "$status"
		fi
	done < <(sort -u "$outputs_file")
}

_require() {
	local missing_bin=0
	local bin

	for bin in "$@"; do
		if ! command -v "$bin" > /dev/null 2>&1; then
			missing_bin=1
			_error "Required: $bin"
		fi
	done

	if [ $missing_bin -ne 0 ]; then
		_fatal "$E_MISSING_APP" "One or more executables or apps are missing."
	fi
}

_imgmod_output_format() {
	local output=$1
	local ext

	if [ -n "$output" ] && [[ "$(basename "$output")" == *.* ]]; then
		ext="${output##*.}"
		ext="${ext,,}"
		[ "$ext" = jpeg ] && ext=jpg
		_echo "$ext"
		return
	fi

	_echo jpg
}

_imgmod_validate_format() {
	local format=$1

	if [[ ! "$format" =~ ^[A-Za-z0-9]+$ ]]; then
		_fatal $E_ARGS "Invalid format: $format"
	fi
}
