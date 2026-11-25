# Build status

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
- The Windows Media Foundation helper passed `cargo check --locked --manifest-path packaging/windows-encoder/Cargo.toml --target x86_64-pc-windows-msvc` on the Mac. This is a type check only.
- Beta gate remains open. Next run the packaged desktop smoke test with outbound network denied, confirm clean cancellation and decoded loop timing, and build the release bundle. Windows runtime, playback in ProPresenter/OBS, clean-machine installation and physical display checks remain outstanding. ProRes and live output remain future work.
