#!/usr/bin/env python3
"""Render a configurable FIGlet clock."""

from __future__ import annotations

import argparse
from datetime import datetime
from functools import cache
import os
import select
import secrets
import shlex
import shutil
import subprocess
import sys
import termios
import time
import tty

FIGLET_WIDTH = 10_000
DEFAULT_FORMAT = "%Y-%m-%d\\r%H:%M:%S"
EXIT_FONT_UNAVAILABLE = 3
EXIT_LOLCAT_UNAVAILABLE = 4
EXIT_LOLCAT_FAILED = 5
EXIT_INVALID_LOLCAT_CONFIGURATION = 6


class ClockError(Exception):
    """A user-facing clock error with a specific exit status."""

    exit_code = 1


class FontUnavailableError(ClockError):
    exit_code = EXIT_FONT_UNAVAILABLE


class LolcatUnavailableError(ClockError):
    exit_code = EXIT_LOLCAT_UNAVAILABLE


class LolcatFailedError(ClockError):
    exit_code = EXIT_LOLCAT_FAILED


class LolcatConfigurationError(ClockError):
    exit_code = EXIT_INVALID_LOLCAT_CONFIGURATION


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="timinal",
        description="Display the current time with a FIGlet font.",
        epilog="Use --live for the interactive clock; press Q or Escape to quit it.",
    )
    parser.add_argument("-L", "--live", action="store_true", help="refresh in a centered interactive display")
    parser.add_argument("-d", "--font-dir", metavar="DIRECTORY", help="FIGlet font directory passed to figlet -d")
    parser.add_argument("-f", "--font", metavar="FONT", help="FIGlet font passed to figlet -f")
    parser.add_argument(
        "-F",
        "--format",
        default=DEFAULT_FORMAT,
        metavar="FORMAT",
        help=r"strftime format; \r starts a new FIGlet block (default: %(default)s)",
    )
    parser.add_argument("-a", "--lolcat", action="store_true", help="pipe each rendered frame through lolcat")
    parser.add_argument("-s", "--seed", type=int, metavar="SEED", help="set the lolcat seed when --lolcat is used")
    parser.add_argument("--uppercase", action="store_true", help="display formatted text in uppercase")
    parser.add_argument("--fixed", action="store_true", help="render the selected font in equal-width cells")
    alignment_group = parser.add_mutually_exclusive_group()
    alignment_group.add_argument("-l", "--left", dest="alignment", action="store_const", const="left", help="left-align the clock")
    alignment_group.add_argument("-c", "--center", dest="alignment", action="store_const", const="center", help="center the clock")
    alignment_group.add_argument("-r", "--right", dest="alignment", action="store_const", const="right", help="right-align the clock")
    parser.set_defaults(alignment="left")
    return parser.parse_args()


class KeyReader:
    """Read single keypresses while restoring terminal settings on exit."""

    def __init__(self, enabled: bool) -> None:
        self.enabled = enabled and sys.stdin.isatty()
        self.file_descriptor: int | None = None
        self.settings: list[object] | None = None

    def __enter__(self) -> "KeyReader":
        if self.enabled:
            self.file_descriptor = sys.stdin.fileno()
            self.settings = termios.tcgetattr(self.file_descriptor)
            tty.setcbreak(self.file_descriptor)
        return self

    def __exit__(self, *_: object) -> None:
        if self.file_descriptor is not None and self.settings is not None:
            termios.tcsetattr(self.file_descriptor, termios.TCSADRAIN, self.settings)

    def quit_requested(self) -> bool:
        if self.file_descriptor is None:
            return False
        readable, _, _ = select.select([self.file_descriptor], [], [], 0)
        if not readable:
            return False
        return os.read(self.file_descriptor, 1) in (b"\x1b", b"q", b"Q")


def format_values(format_string: str, uppercase: bool) -> tuple[str, ...]:
    """Format the current time, splitting FIGlet blocks on the \\r escape."""
    values = datetime.now().strftime(format_string.replace(r"\r", "\r")).split("\r")
    return tuple(value.upper() for value in values) if uppercase else tuple(values)


def render_figlet(font_directory: str | None, font: str | None, value: str) -> tuple[str, ...]:
    """Render one value through FIGlet without wrapping."""
    try:
        command = ["figlet", "-w", str(FIGLET_WIDTH)]
        if font_directory is not None:
            command.extend(("-d", font_directory))
        if font is not None:
            command.extend(("-f", font))
        result = subprocess.run(
            [*command, value],
            capture_output=True,
            check=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise FontUnavailableError("figlet is not installed") from error
    except subprocess.CalledProcessError as error:
        requested_font = f" font {font!r}" if font is not None else " default font"
        raise FontUnavailableError(f"could not render with FIGlet{requested_font}") from error
    return tuple(result.stdout.splitlines())


@cache
def fixed_font(font_directory: str | None, font: str | None) -> tuple[int, int, dict[str, tuple[str, ...]]]:
    """Measure printable glyphs and center each in one common cell width."""
    glyphs = {character: render_figlet(font_directory, font, character) for character in map(chr, range(32, 127))}
    height = max(len(glyph) for glyph in glyphs.values())
    cell_width = max(len(row) for glyph in glyphs.values() for row in glyph)
    centered_glyphs = {}
    for character, glyph in glyphs.items():
        glyph_width = max((len(row.rstrip()) for row in glyph), default=0)
        left_padding = (cell_width - glyph_width) // 2
        right_padding = cell_width - glyph_width - left_padding
        centered_glyphs[character] = tuple(
            " " * left_padding + row.rstrip().ljust(glyph_width) + " " * right_padding for row in glyph
        ) + (" " * cell_width,) * (height - len(glyph))
    return height, cell_width, centered_glyphs


def render_fixed(font_directory: str | None, font: str | None, value: str) -> list[str]:
    """Render text from the selected font's cached, equal-width cells."""
    height, _cell_width, glyphs = fixed_font(font_directory, font)
    try:
        return ["".join(glyphs[character][row] for character in value) for row in range(height)]
    except KeyError as error:
        raise FontUnavailableError(f"fixed rendering supports printable ASCII only: {error.args[0]!r}") from error


def render(font_directory: str | None, font: str | None, columns: int, format_string: str, uppercase: bool, fixed: bool) -> list[str]:
    """Render formatted clock blocks without FIGlet wrapping and crop each row."""
    lines: list[str] = []
    for value in format_values(format_string, uppercase):
        rendered = render_fixed(font_directory, font, value) if fixed else render_figlet(font_directory, font, value)
        lines.extend(line[:columns] for line in rendered)
    return lines


def align_frame(frame: list[str], alignment: str) -> tuple[list[str], int]:
    """Align each row within the widest rendered row."""
    block_width = max(map(len, frame), default=0)
    if alignment == "left":
        return frame, block_width
    if alignment == "center":
        return [" " * ((block_width - len(line)) // 2) + line for line in frame], block_width
    return [" " * (block_width - len(line)) + line for line in frame], block_width


def lolcat_arguments(enabled: bool, seed: int | None) -> list[str] | None:
    """Return configured lolcat arguments when rainbow output is enabled."""
    if not enabled:
        return None
    try:
        arguments = shlex.split(os.environ.get("TIMINAL_LOLCAT_ARGS", ""))
    except ValueError as error:
        raise LolcatConfigurationError(f"invalid TIMINAL_LOLCAT_ARGS: {error}") from error
    if not any(argument == "--seed" or argument.startswith("--seed=") for argument in arguments):
        arguments.extend(("--seed", str(seed if seed is not None else secrets.randbits(32))))
    return arguments


def require_lolcat(enabled: bool) -> None:
    """Fail before rendering when rainbow output was requested but is unavailable."""
    if enabled and shutil.which("lolcat") is None:
        raise LolcatUnavailableError("lolcat is not installed")


def write_frame(output: str, lolcat_args: list[str] | None, *, prefix: str = "") -> None:
    """Write a complete frame atomically, optionally colored through lolcat."""
    if lolcat_args is None:
        sys.stdout.write(prefix + output + "\n")
        sys.stdout.flush()
        return
    try:
        result = subprocess.run(
            ["lolcat", "--force", *lolcat_args],
            capture_output=True,
            input=output + "\n",
            text=True,
            check=True,
        )
    except FileNotFoundError as error:
        raise LolcatUnavailableError("lolcat is not installed") from error
    except subprocess.CalledProcessError as error:
        raise LolcatFailedError(f"lolcat exited with status {error.returncode}") from error
    sys.stdout.write(prefix + result.stdout)
    sys.stdout.flush()


def draw(font_directory: str | None, font: str | None, live: bool, format_string: str, uppercase: bool, fixed: bool, alignment: str, lolcat_args: list[str] | None) -> None:
    columns, rows = shutil.get_terminal_size(fallback=(80, 24))
    frame = render(font_directory, font, columns, format_string, uppercase, fixed)
    frame, block_width = align_frame(frame, alignment)
    if not live:
        write_frame("\n".join(frame), lolcat_args)
        return
    block_padding = max((columns - block_width) // 2, 0)
    top_padding = max((rows - len(frame)) // 2, 0)
    output = [""] * top_padding
    output.extend(" " * block_padding + line for line in frame)
    write_frame("\n".join(output), lolcat_args, prefix="\033[H\033[J")


def wait_until_next_update(key_reader: KeyReader) -> bool:
    """Wait for the next second boundary without accumulating render drift."""
    target = int(time.time()) + 1
    while True:
        if key_reader.quit_requested():
            return True
        remaining = target - time.time()
        if remaining <= 0:
            return False
        time.sleep(min(remaining, 0.05))


def main() -> None:
    args = parse_args()
    try:
        require_lolcat(args.lolcat)
        configured_lolcat_args = lolcat_arguments(args.lolcat, args.seed)
        if not args.live:
            draw(args.font_dir, args.font, False, args.format, args.uppercase, args.fixed, args.alignment, configured_lolcat_args)
            return
        with KeyReader(enabled=True) as key_reader:
            while True:
                draw(args.font_dir, args.font, True, args.format, args.uppercase, args.fixed, args.alignment, configured_lolcat_args)
                if wait_until_next_update(key_reader):
                    return
    except KeyboardInterrupt:
        return
    except ClockError as error:
        print(f"timinal: {error}", file=sys.stderr)
        raise SystemExit(error.exit_code) from error


if __name__ == "__main__":
    main()
