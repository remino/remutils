# addwatermark

Compatibility command for adding an image watermark.

`addwatermark` has merged into the [`imgmod`](../imgmod/README.md) `watermark`
plugin. Install `imgmod` for new setups:

```sh
brew install remino/remino/imgmod
```

Use the canonical command for new scripts:

```sh
imgmod watermark -w logo.png -o photo-watermarked.jpg photo.jpg
```

The legacy command remains available with its original argument order:

```sh
addwatermark logo.png photo.jpg photo-watermarked.jpg
```

See `imgmod watermark -h` for all options.
