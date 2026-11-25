# Build status

Run started November 26, 2026 at 09:10 AEST. Hard stop at 14:10 AEST.

## Native rendering spike

- `cargo run --offline --release --example spike` passed on Intel macOS with Iris Plus Graphics 640 using Metal. Thirty Aurora frames averaged 19.75 ms at 1920×1080 and 27.63 ms at 3840×960, including readback. The normalized start/end frames matched byte for byte, and a frame sampled a quarter of the way through differed.
- The spike generates two PNGs in the ignored `artifacts/` directory.
- Next checkpoint: compile the Tauri editor and verify that low-resolution preview driven by the same native shader can use the normal app IPC path. Windows runtime is outstanding.
