# Sanctuary Motion

An offline desktop studio for creating seamless worship backgrounds. Choose a look, adjust its palette and motion, check lyric readability, and export at the exact size of your screen. See the [build plan](BUILD_PLAN.md).

## Make a loop

1. Choose a **Look**, then apply an optional surface **Finish**.
2. Set **Color** and **Motion**. Use **Text** to create an optional title, ticker, scroll, or patterned text layer. **Preview lyrics** is a separate readability guide.
3. In **Screen**, pick a size or enter exact pixels. Add a local PNG, JPEG or vector SVG overlay if you need a logo or frame.
4. Choose **Export background** and save an MP4 loop or PNG still. Use the export checkboxes to include the text and image layers. The editor preserves existing output files.

Use **Save project** to keep a reusable design in a local `.sanctuary` file. The sample lyrics show in the preview only. Image overlays stay attached to the current app session. The app renders and encodes media on the machine.

## Build locally

Install Node.js 20+, Rust and the native [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/). On macOS, the encoder build uses the Xcode command-line toolchain. On Windows, it uses Rust with the MSVC target and the installed Windows Media Foundation runtime.

```sh
npm ci
npm run desktop -- dev
npm run desktop -- build
```

Tauri puts platform bundles in `src-tauri/target/release/bundle/`. The build packages a small native H.264 encoder using AVFoundation on macOS or Media Foundation on Windows. FFmpeg is used by the media verification script and is not an app runtime dependency.

## Verify

- `cargo run --release --example spike` checks renderer animation and timing. It creates Aurora samples in the ignored `artifacts/` directory.
- `npm run desktop -- build --features smoke` builds the opt-in test version. On macOS, run `node packaging/verify-smoke.mjs 'src-tauri/target/release/bundle/macos/Sanctuary Motion.app/Contents/MacOS/sanctuary-motion' --deny-network`. On Windows, pass the full path of the built smoke executable without the macOS network flag. The validation command needs `ffmpeg` and `ffprobe` on your development machine.
- Build without `--features smoke` to produce a handoff bundle. Check [build status](BUILD_STATUS.md) for platform verification and open gates.
