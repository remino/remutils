# imgmod

Image modification helpers.

Rémino Rem <https://remino.net/>, 2026

<!-- mtoc-start -->

- [Installation](#installation)
    - [Homebrew](#homebrew)
    - [Download](#download)
    - [Git clone](#git-clone)
- [Usage](#usage)
    - [Completions](#completions)
        - [Bash](#bash)
        - [Zsh](#zsh)
        - [Fish](#fish)
    - [New Plugins](#new-plugins)
    - [Plugins](#plugins)
    - [Plugin Hooks](#plugin-hooks)
    - [socshare](#socshare)

<!-- mtoc-end -->

## Installation

### Homebrew

```sh
brew install remino/remino/imgmod
imgmod
```

### Download

Go to the
[GitHub download page](https://github.com/remino/remutils/releases/latest) for
the latest release, and download the source code from there.

### Git clone

```sh
git clone git@github.com:remino/remutils.git
cd remutils/imgmod
./imgmod
```

## Usage

Run `imgmod` without arguments to see how to use it.

Use `-o` before a command to optimize image outputs reported by that command
with `image_optim`:

```sh
imgmod -o socshare image.png
```

Plugins report optimizable image output with the shared hook:

```sh
imgmod_output "$file"
```

Only files reported through this hook are optimized.

### Completions

Homebrew installs Bash, Zsh, and Fish completion files automatically. If your
shell is already configured to load Homebrew completions, restart the shell and
completion should work:

```sh
imgmod <Tab>
imgmod help <Tab>
imgmod socshare -<Tab>
```

For manual setup, add the command for your shell to its startup file.

#### Bash

```sh
source <(imgmod completion bash)
```

Add that line to `~/.bashrc` or `~/.bash_profile` to load it in new shells.

#### Zsh

```sh
eval "$(imgmod completion zsh)"
```

Add that line to `~/.zshrc` to load it in new shells.

#### Fish

```fish
imgmod completion fish | source
```

Add that line to `~/.config/fish/config.fish` to load it in new shells.

Completions include bundled commands and executable plugins found in XDG plugin
directories. Completion candidates come from the bundled `completion` plugin:

```sh
imgmod completion commands
```

The generated shell scripts can also be inspected directly:

```sh
imgmod completion bash
imgmod completion zsh
imgmod completion fish
```

### New Plugins

Create a plugin in your XDG data directory:

```sh
imgmod newplugin watermark
# ~/.local/share/imgmod/plugins/imgmod-watermark
```

Create a plugin at an exact relative or absolute path:

```sh
imgmod newplugin ./watermark
imgmod newplugin /absolute/path/watermark
```

Use a custom Mustache template:

```sh
imgmod newplugin -t ./plugin.mustache watermark
```

`imgmod -n watermark` is a shortcut for `imgmod newplugin watermark`.

Existing files are not overwritten.

### Plugins

`imgmod` commands are executable plugin files named `imgmod-<command>`. Bundled
plugins are installed next to the `imgmod` wrapper, and local plugins can be
added under XDG data directories:

```sh
~/.local/share/imgmod/plugins/imgmod-watermark
```

Run a plugin by name:

```sh
imgmod watermark image.png
```

That command resolves to an executable named `imgmod-watermark`.

Plugin lookup order allows local commands to override bundled commands:

1. `$XDG_DATA_HOME/imgmod/plugins`, defaulting to
   `$HOME/.local/share/imgmod/plugins`.
2. Each `$XDG_DATA_DIRS` entry with `/imgmod/plugins` appended, defaulting to
   `/usr/local/share/imgmod/plugins` and `/usr/share/imgmod/plugins`.
3. Bundled plugins next to the `imgmod` script.

Bundled plugins source `lib/imgmod.sh` for common helpers. Local plugins can
source that library too, or remain standalone if they do not need shared
helpers.

### Plugin Hooks

Plugins that use `lib/imgmod.sh` should define hooks using the normalized plugin
prefix and call `imgmod_plugin_run "$@"` at the end:

```sh
watermark_start() {
    imgmod_output "$file"
}

imgmod_plugin_run "$@"
```

For a plugin named `watermark`, `PLUGIN_PREFIX` is `watermark`. For a plugin
named `socshare`, `PLUGIN_PREFIX` is `socshare`. Define `<prefix>_help` to show
plugin-specific usage. Use `imgmod_output "$file"` for image files that can be
optimized with `imgmod -o`.

### socshare

```sh
imgmod socshare [-f <format>] <input> [output]
```

Crop and resize an image to `1200x630` for Open Graph and Twitter cards.

When `output` is omitted, the output path is generated from the input path:

```sh
imgmod socshare image.png
# image-pubshare.jpg
```

Use `-f` to select a different output format:

```sh
imgmod socshare -f png image.png
# image-pubshare.png
```
