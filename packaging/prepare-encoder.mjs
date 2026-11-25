import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const folder = join(root, 'src-tauri', 'binaries');
const requested = process.env.TAURI_ENV_TARGET_TRIPLE;

if (process.platform === 'darwin') {
  mkdirSync(folder, { recursive: true });
  const architecture = { x64: 'x86_64', arm64: 'aarch64' };
  const targets = requested === 'universal-apple-darwin'
    ? ['aarch64-apple-darwin', 'x86_64-apple-darwin']
    : [requested ?? `${architecture[process.arch]}-apple-darwin`];
  for (const triple of targets) {
    const cpu = triple.startsWith('aarch64') ? 'arm64' : 'x86_64';
    execFileSync('xcrun', [
      'swiftc', '-O', '-target', `${cpu}-apple-macos11.0`,
      join(root, 'packaging', 'Encoder.swift'),
      '-o', join(folder, `sanctuary-encoder-${triple}`),
    ], { stdio: 'inherit' });
  }
} else if (process.platform === 'win32') {
  mkdirSync(folder, { recursive: true });
  const triple = requested ?? execFileSync('rustc', ['--print', 'host-tuple'], { encoding: 'utf8' }).trim();
  const cargo = join(root, 'packaging', 'windows-encoder');
  const target = join(cargo, 'target');
  execFileSync('cargo', [
    'build', '--locked', '--release', '--target', triple, '--target-dir', target,
    '--manifest-path', join(cargo, 'Cargo.toml'),
  ], { stdio: 'inherit' });
  copyFileSync(join(target, triple, 'release', 'sanctuary-encoder.exe'),
    join(folder, `sanctuary-encoder-${triple}.exe`));
}
