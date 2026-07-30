# vid2gif

Convert video files into animated GIFs.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Download](#download)
    - [Git clone](#git-clone)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/vid2gif
vid2gif input.mp4
```

Homebrew also installs `movie2gif` as an alias for `vid2gif`, so existing
scripts continue to work.

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/vid2gif
./vid2gif input.mp4
```

## Usage

Convert a video, writing the GIF alongside it by default:

```sh
vid2gif input.mp4
```

Pass an output filename as the second argument:

```sh
vid2gif input.mp4 output.gif
```

Use `-s` and `-d` to select a clip, then adjust frame rate and dimensions:

```sh
vid2gif -s 3 -d 5 -r 15 -w 640 input.mp4 clip.gif
```

`vid2gif` generates an FFmpeg palette for good GIF colours and optimizes the
result with `image_optim` when it is available. Use `-O`, `--optim`, or
`--optimize` to require optimization; use `--no-optim` or `--no-optimize` to
skip it. `--auto-optim` and `--auto-optimize` restore the default automatic
behavior. Run `vid2gif --help` for all options.
