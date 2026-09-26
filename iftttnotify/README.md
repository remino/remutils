# iftttnotify

Send notifications to IFTTT Webhooks from the command line.

- <https://remino.net/iftttnotify/>
- [Source code](https://github.com/remino/remutils/tree/main/iftttnotify)

2026 Rémino Rem <https://remino.net/>

---

<!-- mtoc-start -->

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)

<!-- mtoc-end -->

## Installation

```sh
brew install remino/remino/iftttnotify
```

Or run it directly from a clone:

```sh
git clone git@github.com:remino/remutils.git
cd remutils/iftttnotify
./iftttnotify -h
```

## Configuration

Create a Webhooks applet in IFTTT and copy its key from the
[Webhooks settings page](https://ifttt.com/services/maker_webhooks/settings).
Set it for one command or save it in `~/.ifttt-webhooks-key`:

```sh
export IFTTT_WEBHOOKS_KEY='your-key'
```

`iftttnotify` also reads `~/.config/ifttt-webhooks-key` and
`/etc/ifttt-webhooks-key`, in that order. Keep these files private.

## Usage

Send up to three values to the default `notify` event:

```sh
iftttnotify 'Build complete' main success
```

Use `-e` to select another event, or `-r` for the `rich_notify` event:

```sh
iftttnotify -e deploy 'Production deployment complete'
iftttnotify -r 'A rich notification'
```

Run `man iftttnotify` or `iftttnotify -h` for the full reference.
