# Sanctuary Motion build plan

## First release

Build an offline editor for preparing worship loops before a service. Ship six looks: aurora, silk, bokeh, dust, fog and light rays. Include palette, intensity, motion and seed controls, a preview-only lyric overlay, and local project save and load. Export H.264 MP4 and PNG first, then add ProRes 422 MOV after checking the packaging and playback workflow. Treat live stage output, cue triggering and audio reactivity as a separate milestone.

## Architecture

- Tauri with a React and TypeScript editor. Start with a GPU proof of concept on macOS and Windows. Evaluate native Rust `wgpu` with WGSL for deterministic export and compare it with WebGPU preview inside the webview. If webview support or preview parity fails, keep the renderer native and validate the preview transport before building the editor.
- Use one versioned scene specification for preview and export. Store the preset ID and version, palette, seed, motion settings, dimensions, FPS and duration in local JSON. Keep lyric preview settings out of the renderer's export configuration.
- Render at the requested width and height. Compose in aspect-aware coordinates with a shared focal point. Offer 16:9, 21:9, 32:9, 9:16 and 1:1 presets plus custom pixel sizes. Report hardware and codec limits before render. For H.264 with 4:2:0 chroma, require even dimensions and offer PNG for exact odd dimensions.
- Drive motion with periodic functions at phase `frame / frameCount`. Export frames `0` through `frameCount - 1` at fixed FPS. The phase at `frameCount` must match phase zero and is omitted to avoid a duplicated frame. Use whole cycles per loop and tune perceived speed through motion amplitude and cycle count.
- Feed frames through a bounded queue to a local encoder. Bundle an encoder only after reviewing its build and redistribution requirements. Show progress and cancellation, write to a temporary file beside the destination, and publish the output only after successful encoding. Preserve existing files unless the operator chooses to replace them.

## Build order

1. **Rendering spike.** Produce one Aurora loop at 1920×1080 and 3840×960 on both target platforms. Verify loop timing, frame readback throughput and preview/export parity before committing to the preview approach.
2. **Editor.** Add preset selection, palette and motion controls, seeded variation, exact dimensions, a lyric readability preview and keyboard-accessible controls. Save and reopen local projects.
3. **Export.** Add MP4 and PNG, destination selection, progress and cancellation. Test decoder playback in ProPresenter and OBS. Add ProRes after the same checks pass.
4. **Preset library and release.** Finish the six looks, verify each on landscape, ultrawide and portrait canvases, and package self-contained macOS and Windows builds. Document tested operating systems and hardware.
5. **Live mode.** Test fullscreen output on a second display, black and freeze controls, cue transitions and display disconnect recovery. Evaluate MIDI or OSC after output is stable. Keep the export workflow usable independently.

## Release checks

- On a clean machine with networking disabled, launch, edit, save, reopen and export without prompts to download assets or encoders.
- Check output dimensions, FPS and frame count with a media probe. Compare phase zero and one before encoding, then watch the encoded seam in the target player. Verify that the lyric preview is absent from exported files.
- Test a 16:9 projector, a portrait display and an exact ultrawide LED-wall size for shape distortion, focal point placement and readability. Reopening a saved project should reproduce the scene on the same renderer version.
- Test cancellation, low disk space, unsupported canvas dimensions and encoder failure. Confirm the editor stays responsive and any prior export remains intact.
