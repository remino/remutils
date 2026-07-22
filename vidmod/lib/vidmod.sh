#!/usr/bin/env bash
# Shared helpers for vidmod and its plugins.

E_ARGS=16
E_NO_FILE=17
E_MISSING_APP=19
E_PROCESSING=20

VIDMOD_PLUGIN_PREFIX="${VIDMOD_PLUGIN_PREFIX:-vidmod-}"

APP_NAME="${VIDMOD_APP_NAME:-vidmod}"
PLUGIN_NAME="${VIDMOD_PLUGIN_NAME:-$(basename "$0")}"
[[ "$PLUGIN_NAME" == "$VIDMOD_PLUGIN_PREFIX"* ]] && PLUGIN_NAME="${PLUGIN_NAME#"$VIDMOD_PLUGIN_PREFIX"}"
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

vidmod_overwrite_mode() {
	_echo "${VIDMOD_OVERWRITE_MODE:-prompt}"
}

vidmod_ffmpeg_overwrite_args() {
	local output=$1
	local mode

	mode="$(vidmod_overwrite_mode)"

	if [ "$mode" = force ] || [ "${VIDMOD_OVERWRITE_APPROVED_OUTPUT:-}" = "$output" ]; then
		_echo -y
	fi
}

vidmod_prepare_output() {
	local output=$1
	local mode
	local reply=

	[ ! -e "$output" ] && return
	[ "${VIDMOD_OVERWRITE_APPROVED_OUTPUT:-}" = "$output" ] && return

	mode="$(vidmod_overwrite_mode)"

	case "$mode" in
		force)
			export VIDMOD_OVERWRITE_APPROVED_OUTPUT="$output"
			return
			;;
		no-clobber)
			_fatal "$E_PROCESSING" "Output file already exists: $output"
			;;
		interactive)
			if [ ! -t 0 ] || [ ! -t 2 ]; then
				_fatal "$E_PROCESSING" "Interactive overwrite requested, but no TTY is available: $output"
			fi
			;;
		prompt)
			if [ ! -t 0 ] || [ ! -t 2 ]; then
				_fatal "$E_PROCESSING" "Output file already exists: $output. Use -y/--overwrite to overwrite or -N/--no-overwrite to fail without prompting."
			fi
			;;
		*)
			_fatal "$E_ARGS" "Invalid overwrite mode: $mode"
			;;
	esac

	if [ -w /dev/tty ] && [ -r /dev/tty ]; then
		printf 'Overwrite existing file? [y/N] %s\n' "$output" > /dev/tty
		read -r reply < /dev/tty
	else
		printf 'Overwrite existing file? [y/N] %s\n' "$output" >&2
		read -r reply
	fi
	case "${reply,,}" in
		y | yes)
			export VIDMOD_OVERWRITE_APPROVED_OUTPUT="$output"
			;;
		*)
			_fatal "$E_PROCESSING" "Not overwriting existing file: $output"
			;;
	esac
}

vidmod_plugin_run() {
	local start_hook="${PLUGIN_PREFIX}_start"
	local help_hook="${PLUGIN_PREFIX}_help"

	trap _exit INT TERM

	case "${1:-}" in
		-v | --version)
			vidmod_plugin_version
			return
			;;
	esac

	if declare -F "$start_hook" > /dev/null 2>&1; then
		"$start_hook" "$@"
		return
	fi

	if declare -F "$help_hook" > /dev/null 2>&1; then
		"$help_hook"
	fi

	return $E_ARGS
}

vidmod_plugin_version() {
	if [ -n "${VERSION:-}" ]; then
		_echo "$USAGE_NAME $VERSION"
	else
		_echo "$USAGE_NAME"
	fi
}

vidmod_plugin_dirs() {
	local data_home
	local data_dirs
	local dir

	data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
	data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

	_echo "$data_home/vidmod/plugins"

	IFS=: read -ra dirs <<< "$data_dirs"
	for dir in "${dirs[@]}"; do
		[ -z "$dir" ] && continue
		_echo "$dir/vidmod/plugins"
	done

	if [ -n "${VIDMOD_PLUGIN_DIR:-}" ]; then
		_echo "$VIDMOD_PLUGIN_DIR"
	fi
}

vidmod_find_plugin() {
	local command_name=$1
	local dir
	local plugin

	while IFS= read -r dir; do
		plugin="$dir/$VIDMOD_PLUGIN_PREFIX$command_name"
		if [ -f "$plugin" ] && [ -x "$plugin" ]; then
			_echo "$plugin"
			return
		fi
	done < <(vidmod_plugin_dirs)
}

vidmod_list_commands() {
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
			[[ "$command_name" == "$VIDMOD_PLUGIN_PREFIX"* ]] || continue
			command_name="${command_name#"$VIDMOD_PLUGIN_PREFIX"}"

			case " $seen " in
				*" $command_name "*) continue ;;
			esac

			seen="$seen$command_name "
			_echo "$command_name"
		done
	done < <(vidmod_plugin_dirs)
}

vidmod_legacy_start() {
	local change_name=$1
	local output=
	local ffmpeg_extra_opts=
	local opt
	local input

	shift

	OPTIND=1
	while getopts :f:ho: opt; do
		case $opt in
			f) ffmpeg_extra_opts="$OPTARG" ;;
			h)
				vidmod_legacy_help "$change_name"
				return
				;;
			o) output="$OPTARG" ;;
			:) vidmod_legacy_invalid_opt "$OPTARG" "$change_name" ;;
			*) vidmod_legacy_invalid_opt "$OPTARG" "$change_name" ;;
		esac
	done

	shift "$((OPTIND - 1))"

	[ $# -lt 1 ] && vidmod_legacy_help "$change_name" && return $E_ARGS
	[ $# -gt 1 ] && vidmod_legacy_help "$change_name" && return $E_ARGS

	input=$1
	[ -f "$input" ] || _fatal "$E_NO_FILE" "File not found: $input"

	if [ -z "$output" ]; then
		output="$(vidmod_legacy_output_path "$input" "$change_name")"
	fi

	vidmod_prepare_output "$output"

	_echo "<= $input"
	_echo "=> $output"

	vidmod_legacy_apply "$change_name" "$input" "$output" "$ffmpeg_extra_opts"
}

vidmod_legacy_help() {
	local change_name=$1

	cat << USAGE
$USAGE_NAME $VERSION

USAGE: $USAGE_NAME [<options>] [-o <output>] <input>

Apply the old vidmod "$change_name" change to one video file.

OPTIONS:

	-f        Extra ffmpeg options.
	-h        Show this help screen.
	-o        Output video file.
	-v        Show plugin name and version number.

USAGE
}

vidmod_legacy_invalid_opt() {
	local invalid_opt=$1
	local change_name=$2

	_error "Invalid option: -$invalid_opt"
	_echo
	vidmod_legacy_help "$change_name"
	exit $E_ARGS
}

vidmod_legacy_output_path() {
	local input=$1
	local change_name=$2
	local output_dir
	local input_name
	local input_noext
	local input_ext

	output_dir="$(dirname "$input")"
	input_name="$(basename "$input")"
	input_noext="$(echo "$input_name" | sed 's/\.[^.]*$//g')"
	input_ext="$(echo "$input_name" | grep -o '\.[^.]*$')"

	case "$change_name" in
		hevc | mp4 | qt) _echo "$output_dir/$input_noext.mp4" ;;
		*) _echo "$output_dir/$input_noext-$change_name$input_ext" ;;
	esac
}

vidmod_legacy_apply() {
	local change_name=$1
	local input=$2
	local output=$3
	local ffmpeg_extra_opts=$4

	case "$change_name" in
		169) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf "crop='if(gte(iw/ih,16/9),ih*16/9,iw)':'if(gte(iw/ih,16/9),ih,iw*9/16)',setsar=1" ;;
		43) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf "crop='if(gte(iw/ih,4/3),ih*4/3,iw)':'if(gte(iw/ih,4/3),ih,iw*3/4)',setsar=1" ;;
		60fps) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -r 60 ;;
		audio) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vn -acodec copy ;;
		butter) butterflow "$input" -r 120 -audio --levels 6 -o "$output" ;;
		crop219) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -filter:v "crop=iw:iw/21*9" ;;
		crossfade) vidcrossfade -f 2 -o "$output" "$input" ;;
		hevc) vidmod_ffmpeg_hevc "$input" "$output" "$ffmpeg_extra_opts" ;;
		loop) vidmod_ffmpeg_loop "$input" "$output" "$ffmpeg_extra_opts" ;;
		mono) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -ac 1 ;;
		mp4) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" ;;
		mute) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -an -c copy ;;
		qt) vidmod_ffmpeg_qt "$input" "$output" "$ffmpeg_extra_opts" ;;
		reverse) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf reverse -af areverse ;;
		rotate90) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf "transpose=1" ;;
		rotate180) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf "transpose=1,transpose=1" ;;
		rotate270) vidmod_ffmpeg "$input" "$output" "$ffmpeg_extra_opts" -vf "transpose=2" ;;
		slowdown) vidmod_ffmpeg_slowdown "$input" "$output" "$ffmpeg_extra_opts" ;;
		twitter) vidmod_ffmpeg_twitter "$input" "$output" "$ffmpeg_extra_opts" ;;
		*) _fatal "$E_ARGS" "Invalid change: $change_name" ;;
	esac
}

vidmod_ffmpeg_args() {
	local ffmpeg_extra_opts=$1

	VIDMOD_FFMPEG_ARGS=(-hide_banner -loglevel panic -nostdin)
	local overwrite_arg=

	overwrite_arg="$(vidmod_ffmpeg_overwrite_args "$2")"
	[ -n "$overwrite_arg" ] && VIDMOD_FFMPEG_ARGS+=("$overwrite_arg")

	[ -n "$ffmpeg_extra_opts" ] || return

	# Preserve vidmod 1 behavior: split extra ffmpeg options on shell words.
	# shellcheck disable=SC2206
	local extra_args=($ffmpeg_extra_opts)
	VIDMOD_FFMPEG_ARGS+=("${extra_args[@]}")
}

vidmod_ffmpeg() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3

	shift 3

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	ffmpeg -i "$input" \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		"$@" \
		"$output"
}

vidmod_ffmpeg_hevc() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	ffmpeg -i "$input" -c:v libx265 -c:a aac -tag:v hvc1 \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		"$output"
}

vidmod_ffmpeg_loop() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3
	local tmpfile

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	tmpfile="$(mktemp ".vidmod.XXXXXX")"

	for _ in 1 2; do
		printf "file '%s'\n" "$input" >> "$tmpfile"
	done

	ffmpeg -f concat -safe 0 -i "$tmpfile" \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		-c copy \
		"$output"
	local status=$?

	rm -f "$tmpfile"
	return "$status"
}

vidmod_ffmpeg_qt() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	ffmpeg -i "$input" -tag:v hvc1 -c copy -c:s mov_text \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		"$output"
}

vidmod_ffmpeg_slowdown() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	ffmpeg -i "$input" -filter:a "atempo=0.8" \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		-filter:v "setpts=1.25*PTS" \
		"$output"
}

vidmod_ffmpeg_twitter() {
	local input=$1
	local output=$2
	local ffmpeg_extra_opts=$3

	vidmod_ffmpeg_args "$ffmpeg_extra_opts" "$output"

	ffmpeg -i "$input" \
		"${VIDMOD_FFMPEG_ARGS[@]}" \
		-vcodec libx264 \
		-vf 'scale=640:trunc(ow/a/2)*2' \
		-acodec aac \
		-vb 1024k \
		-minrate 1024k \
		-maxrate 1024k \
		-bufsize 1024k \
		-ar 44100 \
		-strict experimental \
		-r 30 \
		"$output"
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
