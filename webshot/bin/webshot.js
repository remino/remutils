#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

import puppeteer from 'puppeteer';
import sharp from 'sharp';

const FORMATS = new Set(['png', 'jpeg', 'avif', 'webp']);
const EXTENSION_FORMATS = new Map([
  ['.png', 'png'],
  ['.jpg', 'jpeg'],
  ['.jpeg', 'jpeg'],
  ['.avif', 'avif'],
  ['.webp', 'webp'],
]);

const DEFAULT_WIDTH = 1200;
const DEFAULT_HEIGHT = 630;
const DEFAULT_WAIT_SECONDS = 0;
const DEFAULT_ZOOM = 1;
const DEFAULT_DPI = 96;
const packageJsonPath = new URL('../package.json', import.meta.url);
const { version: VERSION } = JSON.parse(
  await fs.readFile(packageJsonPath, 'utf8'),
);

function usage() {
  return `webshot ${VERSION}

USAGE: webshot [<options>] <url> [<image-file>]

Capture a webpage as an image.

The output image format is inferred from <image-file>, unless -f is set.
Supported formats: png, jpeg, avif, webp.
If <image-file> is omitted, the output file defaults to a PNG name derived from the URL.

OPTIONS:

  -c <css-file>                 Embed CSS file before capture.
  -d <dpi>                      Set screenshot density in DPI. Default: ${DEFAULT_DPI}
  -f <format>                   Override image format.
  -h                            Show this help.
  -H <pixels>                   Set viewport height. Default: ${DEFAULT_HEIGHT}
  -j <js-file>                  Run JavaScript file before capture.
  -W <pixels>                   Set viewport width. Default: ${DEFAULT_WIDTH}
  -w <seconds>                  Wait after page load before capture. Default: ${DEFAULT_WAIT_SECONDS}
  -z <factor>                   Set page zoom factor. Default: ${DEFAULT_ZOOM}
`;
}

function version() {
  return `webshot ${VERSION}\n`;
}

class UsageError extends Error {}

function parsePositiveInteger(value, option) {
  if (!/^\d+$/.test(value)) {
    throw new UsageError(`${option} must be a positive integer.`);
  }

  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new UsageError(`${option} must be a positive integer.`);
  }

  return parsed;
}

function parseNonNegativeFloat(value, option) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new UsageError(`${option} must be a non-negative number.`);
  }

  return parsed;
}

function parsePositiveFloat(value, option) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new UsageError(`${option} must be a positive number.`);
  }

  return parsed;
}

function requireOptionValue(args, index, option) {
  const value = args[index + 1];
  if (value === undefined || value === '' || value.startsWith('-')) {
    throw new UsageError(`${option} requires a value.`);
  }

  return value;
}

function parseArgs(args) {
  const options = {
    width: DEFAULT_WIDTH,
    height: DEFAULT_HEIGHT,
    waitSeconds: DEFAULT_WAIT_SECONDS,
    zoom: DEFAULT_ZOOM,
    dpi: DEFAULT_DPI,
    format: undefined,
    cssFile: undefined,
    jsFile: undefined,
  };
  const positional = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (arg === '-h') {
      return { help: true, options, positional };
    }

    if (arg === '-v') {
      return { version: true, options, positional };
    }

    if (arg === '-W') {
      const value = requireOptionValue(args, index, arg);
      options.width = parsePositiveInteger(value, arg);
      index += 1;
      continue;
    }

    if (arg === '-H') {
      const value = requireOptionValue(args, index, arg);
      options.height = parsePositiveInteger(value, arg);
      index += 1;
      continue;
    }

    if (arg === '-w') {
      const value = requireOptionValue(args, index, arg);
      options.waitSeconds = parseNonNegativeFloat(value, arg);
      index += 1;
      continue;
    }

    if (arg === '-z') {
      const value = requireOptionValue(args, index, arg);
      options.zoom = parsePositiveFloat(value, arg);
      index += 1;
      continue;
    }

    if (arg === '-d') {
      const value = requireOptionValue(args, index, arg);
      options.dpi = parsePositiveFloat(value, arg);
      index += 1;
      continue;
    }

    if (arg === '-f') {
      const value = requireOptionValue(args, index, arg).toLowerCase();
      if (!FORMATS.has(value)) {
        throw new UsageError('-f must be one of: png, jpeg, avif, webp.');
      }

      options.format = value;
      index += 1;
      continue;
    }

    if (arg === '-c') {
      options.cssFile = requireOptionValue(args, index, arg);
      index += 1;
      continue;
    }

    if (arg === '-j') {
      options.jsFile = requireOptionValue(args, index, arg);
      index += 1;
      continue;
    }

    if (arg.startsWith('-')) {
      throw new UsageError(`Unknown option: ${arg}`);
    }

    positional.push(arg);
  }

  return { help: false, options, positional };
}

function normalizeUrl(value) {
  try {
    const normalizedValue = /^[a-zA-Z][a-zA-Z\d+\-.]*:/.test(value)
      ? value
      : `http://${value}`;
    const url = new URL(normalizedValue);
    if (!['http:', 'https:'].includes(url.protocol)) {
      throw new UsageError('url must use http or https.');
    }

    return url.toString();
  } catch (error) {
    if (error instanceof UsageError) {
      throw error;
    }

    throw new UsageError('url must be a valid absolute URL.');
  }
}

function inferFormat(file, override) {
  if (override !== undefined) {
    return override;
  }

  const extension = path.extname(file).toLowerCase();
  const format = EXTENSION_FORMATS.get(extension);
  if (format === undefined) {
    throw new UsageError(
      'Could not infer image format from extension. Use .png, .jpg, .jpeg, .avif, .webp, or pass -f.',
    );
  }

  return format;
}

function inferOutputFile(url, format = 'png') {
  const parsedUrl = new URL(url);
  const segments = [parsedUrl.hostname];
  const pathname = parsedUrl.pathname
    .replace(/\/+/g, '/')
    .replace(/^\/|\/$/g, '');

  if (pathname.length > 0) {
    segments.push(
      ...pathname
        .split('/')
        .map((segment) => path.parse(segment).name)
        .filter(Boolean),
    );
  }

  const baseName = segments
    .join('-')
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^[.-]+|[.-]+$/g, '');

  return `${baseName || 'webshot'}.${format}`;
}

async function injectAssets(page, { cssFile, jsFile }) {
  if (cssFile !== undefined) {
    await page.addStyleTag({ content: await fs.readFile(cssFile, 'utf8') });
  }

  if (jsFile !== undefined) {
    await page.addScriptTag({ content: await fs.readFile(jsFile, 'utf8') });
  }
}

async function applyZoom(page, zoom) {
  if (zoom === DEFAULT_ZOOM) {
    return;
  }

  await page.addStyleTag({
    content: `:root { zoom: ${zoom} !important; }`,
  });
}

async function saveScreenshot(page, outputFile, format) {
  if (format === 'avif') {
    const screenshot = await page.screenshot({
      type: 'png',
      fullPage: false,
    });
    await sharp(screenshot).avif().toFile(outputFile);
    return;
  }

  await page.screenshot({
    path: outputFile,
    type: format,
    fullPage: false,
  });
}

async function capture({ url, outputFile, options }) {
  const browser = await puppeteer.launch({ headless: true });

  try {
    const page = await browser.newPage();
    await page.setViewport({
      width: options.width,
      height: options.height,
      deviceScaleFactor: options.dpi / DEFAULT_DPI,
    });

    await page.goto(url, { waitUntil: 'load' });
    await injectAssets(page, options);
    await applyZoom(page, options.zoom);

    if (options.waitSeconds > 0) {
      await new Promise((resolve) =>
        setTimeout(resolve, options.waitSeconds * 1000),
      );
    }

    const format = inferFormat(outputFile, options.format);
    await fs.mkdir(path.dirname(path.resolve(outputFile)), { recursive: true });
    await saveScreenshot(page, outputFile, format);
  } finally {
    await browser.close();
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    process.stdout.write(usage());
    return;
  }

  const parsed = parseArgs(args);
  if (parsed.help) {
    process.stdout.write(usage());
    return;
  }

  if (parsed.version) {
    process.stdout.write(version());
    return;
  }

  if (parsed.positional.length < 1 || parsed.positional.length > 2) {
    throw new UsageError(
      'Expected one or two arguments: <url> [<image-file>].',
    );
  }

  const url = normalizeUrl(parsed.positional[0]);
  const outputFile =
    parsed.positional[1] ??
    inferOutputFile(url, parsed.options.format ?? 'png');

  await capture({
    url,
    outputFile,
    options: parsed.options,
  });
}

main().catch((error) => {
  if (error instanceof UsageError) {
    process.stderr.write(`${error.message}\n\n${usage()}`);
    process.exitCode = 1;
    return;
  }

  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
});
