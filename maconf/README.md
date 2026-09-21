# maconf

Get and set common macOS preferences from the command line.

- <https://remino.net/maconf/>
- [Source code](https://github.com/remino/remutils/tree/main/maconf)

2026 Rémino Rem <https://remino.net/>

---

<!-- mtoc-start -->

- [Installation](#installation)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/maconf
```

Or run it directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/maconf
./maconf -h
```

## Usage

Run `man maconf` or `maconf -h` for the complete command reference.

Settings without a final value read their current preference; supply a value to
change it. For example:

```sh
maconf dock position left
maconf dock delay short
maconf finder fullpath show
maconf screencapture location "$HOME/Desktop"
```

Some commands restart Finder, the Dock, or SystemUIServer so the change applies
immediately. `maconf users hide` and `maconf users show` require administrator
privileges.
