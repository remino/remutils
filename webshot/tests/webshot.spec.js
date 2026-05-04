import { execFile } from 'node:child_process';
import { createServer } from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';

import sharp from 'sharp';

const execFileAsync = promisify(execFile);
const rootDir = path.resolve(import.meta.dirname, '..');
const binPath = path.join(rootDir, 'bin/webshot.js');
const packageJsonPath = path.join(rootDir, 'package.json');
const fixturesDir = path.join(rootDir, 'tests/fixtures');
const expectedDir = path.join(rootDir, 'tests/expected');
const outputRoot = path.join(rootDir, 'tests/.tmp');

async function runWebshot(args) {
  return execFileAsync(process.execPath, [binPath, ...args], {
    cwd: rootDir,
    timeout: 30000,
  });
}

async function readFixture(name) {
  return fs.readFile(path.join(fixturesDir, name));
}

async function readPackageVersion() {
  const packageJson = JSON.parse(await fs.readFile(packageJsonPath, 'utf8'));
  return packageJson.version;
}

async function startFixtureServer() {
  const server = createServer(async (request, response) => {
    if (request.url === '/page.html') {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(await readFixture('page.html'));
      return;
    }

    response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('not found');
  });

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', resolve);
  });

  const { port } = server.address();
  return {
    url: `http://127.0.0.1:${port}/page.html`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

async function imageRaw(file) {
  return sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
}

async function expectImageToMatch(
  actualFile,
  expectedFile,
  maxAverageDelta = 0,
) {
  const [actual, expected] = await Promise.all([
    imageRaw(actualFile),
    imageRaw(expectedFile),
  ]);

  expect(actual.info.width).toBe(expected.info.width);
  expect(actual.info.height).toBe(expected.info.height);
  expect(actual.info.channels).toBe(expected.info.channels);

  let totalDelta = 0;
  for (let index = 0; index < actual.data.length; index += 1) {
    totalDelta += Math.abs(actual.data[index] - expected.data[index]);
  }

  const averageDelta = totalDelta / actual.data.length;
  expect(averageDelta).toBeLessThanOrEqual(maxAverageDelta);
}

describe('webshot CLI', () => {
  let server;
  let outputDir;

  beforeAll(async () => {
    server = await startFixtureServer();
  });

  afterAll(async () => {
    await server.close();
  });

  beforeEach(async () => {
    await fs.mkdir(outputRoot, { recursive: true });
    outputDir = await fs.mkdtemp(path.join(outputRoot, 'run-'));
  });

  afterEach(async () => {
    await fs.rm(outputDir, { force: true, recursive: true });
  });

  it('prints usage and exits successfully when no arguments are provided', async () => {
    const result = await runWebshot([]);

    expect(result.stdout).toContain('USAGE: webshot');
    expect(result.stderr).toBe('');
  });

  it('prints the version and exits successfully with -v', async () => {
    const version = await readPackageVersion();
    const result = await runWebshot(['-v']);

    expect(result.stdout).toBe(`webshot ${version}\n`);
    expect(result.stderr).toBe('');
  });

  it('captures the fixture page as a stable PNG', async () => {
    const actual = path.join(outputDir, 'fixture.png');

    await runWebshot(['-W', '320', '-H', '180', server.url, actual]);

    await expectImageToMatch(
      actual,
      path.join(expectedDir, 'webshot-320x180.png'),
    );
  });

  it('embeds CSS and JavaScript before capturing', async () => {
    const actual = path.join(outputDir, 'injected.png');

    await runWebshot([
      '-W',
      '320',
      '-H',
      '180',
      '-c',
      path.join(fixturesDir, 'inject.css'),
      '-j',
      path.join(fixturesDir, 'inject.js'),
      server.url,
      actual,
    ]);

    await expectImageToMatch(
      actual,
      path.join(expectedDir, 'injected-320x180.png'),
    );
  });

  it('uses DPI to scale output pixels while preserving viewport size', async () => {
    const actual = path.join(outputDir, 'dpi.png');

    await runWebshot([
      '-W',
      '320',
      '-H',
      '180',
      '-d',
      '192',
      server.url,
      actual,
    ]);

    const metadata = await sharp(actual).metadata();
    expect(metadata.width).toBe(640);
    expect(metadata.height).toBe(360);
  });
});
