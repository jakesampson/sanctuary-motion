# Build status

## FX library and editor workflow in progress

- The library now has 82 catalog entries with stable numeric IDs. The native renderer spike confirmed distinct animated outputs for landscape and ultrawide before the Finish work began.
- Steps 2–4 are wired to preview, saved scenes and native exports. Finish has 47 treatments, Color has Palette, Tint and Gradient Map, and Motion has whole-cycle speed, framing, stop motion and easing.
- In progress: step 5 Text, with native text compositing for optional export. The original sample lyric guide remains preview-only.
- Next: check legacy project loading and run the renderer and offline packaged smoke suites after the Text integration.

Run started November 26, 2026 at 09:10 AEST. Hard stop at 14:10 AEST.

## Native rendering spike

- `cargo run --offline --release --example spike` passed on Intel macOS with Iris Plus Graphics 640 using Metal. Thirty Aurora frames averaged 19.75 ms at 1920×1080 and 27.63 ms at 3840×960, including readback. The normalized start/end frames matched byte for byte, and a frame sampled a quarter of the way through differed.
- The spike generates two PNGs in the ignored `artifacts/` directory.
- Next checkpoint: compile the Tauri editor and verify that low-resolution preview driven by the same native shader can use the normal app IPC path. Windows runtime is outstanding.

## Editor and export implementation

- Tauri/React editor with six procedural looks, palette and motion presets, local projects, preview-only lyrics, custom screen dimensions and a cancellable export queue of one.
- Preview and exports share the native Rust/WGSL renderer. The full editor was informed by the supplied Altar Loops Studio screenshot and uses its own layout, artwork and controls.
- `cargo run --offline --release --example spike` passed with six distinct moving look samples across HD, ultrawide and portrait aspect ratios. The repeat timing run coincided with desktop compilation.
- `npm run build` passed the TypeScript and frontend build. The macOS AVFoundation helper was compiled and independently produced 30-frame H.264 files at 1920×1080, 3840×960, 1080×1920 and 3840×2160, verified with `ffprobe`.
- The Windows Media Foundation helper uses a static MSVC runtime. `cargo check --offline --locked --target x86_64-pc-windows-msvc` from `packaging/windows-encoder` passed on the Mac with the final compiler flags. This is a type check only.

## Packaged Intel Mac verification

- `npm run desktop -- build --debug --bundles app --features smoke` produced a bundle containing its native H.264 helper. On macOS 13.7.8, `node packaging/verify-smoke.mjs 'src-tauri/target/debug/bundle/macos/Sanctuary Motion.app/Contents/MacOS/sanctuary-motion' --deny-network` passed.
- The native webview animated the preview and painted all six thumbnails. The default and 580-pixel layouts fit horizontally. The WKWebView did not expose WebGPU on this Mac.
- The desktop IPC test saved and reopened an edited project, exported exact-size 1920×1080, 3840×960 and 1080×1920 H.264 files, exported a 721×1281 PNG, and rejected unsupported MP4 dimensions, a duplicate filename and a missing destination folder. Cancelling left no output or staging directory and the next export succeeded.
- FFprobe checked frame rate, dimensions, H.264 format and frame counts. The default loop decoded to 450 frames at 30 fps. Its decoded seam delta was 0.270 grayscale levels versus 0.296 for the 95th percentile of adjacent frames inside the loop.
- The same smoke workflow passed with `SANCTUARY_SMOKE_FULL_DISK` pointing to a disposable 16 MiB HFS+ image with 256 KiB free. The window handled the write error and the full destination had no output or staging directory after failure.
- `node packaging/verify-smoke.mjs '<test copy>/Contents/MacOS/sanctuary-motion' --deny-network --missing-encoder` passed with the bundled helper moved out of the test copy. Video export returned an actionable error and PNG export remained usable.
- The same offline smoke test passed against the optimized `--features smoke` macOS bundle. The default loop again measured an encoded seam delta of 0.270 versus 0.296 for the adjacent-frame 95th percentile.

## Local beta candidate

- Built the normal optimized Intel app with `CARGO_NET_OFFLINE=true APPLE_SIGNING_IDENTITY=- npm run desktop -- build --bundles app`. It is ad-hoc signed for local testing. A notarized distribution remains outstanding.
- Local ZIP: `artifacts/Sanctuary-Motion-0.1.0-macOS-Intel.zip`. Extracted the archive and ran `codesign --verify --strict --deep` on the extracted bundle. Both the app and the bundled encoder were present as x86_64 executables. SHA-256: `927d7bb13bc80023f1ce36d2e1821870f4b530d8de5b00557a899176e2cd6f90`.
- The verified Intel Mac candidate is ready for local hands-on testing. This run stopped at the hardware-dependent beta gates listed below.
- Windows and Apple Silicon runtime, playback in ProPresenter/OBS, clean-machine installation and physical display checks remain outstanding. ProRes and live output remain future work.
