async function runSmoke(dir) {
  const invoke = window.__TAURI_INTERNALS__.invoke;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const checks = [];
  const assert = (condition, label) => {
    if (!condition) throw new Error(label);
    checks.push(label);
  };
  const scene = {
    version: 1, look: 0, seed: 1, motion: 1, intensity: 0.75,
    colors: [[8, 12, 27], [39, 96, 132], [116, 225, 186]],
    width: 1920, height: 1080, fps: 30, duration: 1,
  };
  const file = name => dir + '/' + name;
  const exportFile = (name, settings = scene, format = 'mp4') =>
    invoke('export_scene', { request: { scene: settings, path: file(name), format } });
  const errorFrom = promise => promise.then(() => '', error => String(error));
  const waitFor = async (predicate, message) => {
    for (let attempt = 0; attempt < 100; attempt++) {
      if (predicate()) return;
      await sleep(100);
    }
    throw new Error(message);
  };
  const painted = canvas => canvas && canvas.getContext('2d').getImageData(0, 0, 1, 1).data[3] === 255;
  let ok = false;
  let error;
  try {
    await waitFor(() => painted(document.querySelector('.preview-surface canvas')), 'Main canvas was never painted.');
    assert(document.querySelector('h1').textContent === 'Sanctuary Motion', 'Desktop editor loaded in the native webview');
    await waitFor(() => [...document.querySelectorAll('.look canvas')].length === 6 &&
      [...document.querySelectorAll('.look canvas')].every(painted), 'Preset thumbnails were not painted.');
    assert(true, 'Six procedural thumbnails painted');
    const preview = document.querySelector('.preview-surface canvas');
    const sample = () => preview.getContext('2d').getImageData(0, 0, preview.width, preview.height).data;
    const initial = sample();
    await sleep(450);
    const later = sample();
    assert(initial.some((value, index) => later[index] !== value), 'Live preview animated through native IPC');
    assert(document.documentElement.scrollWidth <= innerWidth + 1, 'Default-width editor fits horizontally');
    await invoke('plugin:event|emit', { event: 'smoke-compact' });
    await waitFor(() => innerWidth <= 590, 'Could not test the compact desktop window.');
    assert(document.documentElement.scrollWidth <= innerWidth + 1, 'Compact-width editor fits horizontally');

    const edited = { ...scene, look: 1, seed: 12, motion: 2, width: 3840, height: 960 };
    const path = file('ultrawide.sanctuary');
    await invoke('save_project', { path, scene: edited });
    const reopened = await invoke('open_project', { path });
    assert(Object.keys(edited).every(key => JSON.stringify(reopened[key]) === JSON.stringify(edited[key])), 'Edited project saves and reopens exactly');
    assert((await errorFrom(invoke('open_project', { path: file('absent.sanctuary') }))).length > 0, 'Missing project reports an error');
    for (const [name, width, height] of [['landscape', 1920, 1080], ['ultrawide', 3840, 960], ['portrait', 1080, 1920]]) {
      const settings = { ...scene, width, height };
      await exportFile(name + '.mp4', settings);
      assert(true, name + ' MP4 export completed');
    }
    await exportFile('default-loop.mp4', { ...scene, duration: 15 });
    assert(true, 'Default 15-second landscape loop exported');
    await exportFile('odd.png', { ...scene, width: 721, height: 1281 }, 'png');
    assert(true, 'Odd portrait PNG export completed');
    assert((await errorFrom(exportFile('odd.mp4', { ...scene, width: 721 }))).includes('requires even'), 'Odd MP4 dimensions reject before encoding');
    assert((await errorFrom(exportFile('landscape.mp4'))).includes('already exists'), 'Existing export protected');
    assert((await errorFrom(exportFile('missing-directory/fail.mp4'))).includes('output folder'), 'Invalid destination reports an error');
    const pending = errorFrom(exportFile('cancelled.mp4', { ...scene, duration: 30 }));
    await sleep(500);
    await invoke('cancel_export');
    assert(await pending === 'Export cancelled.', 'Long export cancelled');
    await exportFile('recovery.png', { ...scene, width: 640, height: 360 }, 'png');
    assert(true, 'A subsequent export succeeded after cancellation');
    ok = true;
  } catch (cause) {
    error = String(cause);
  } finally {
    await invoke('plugin:event|emit', {
      event: 'smoke-result',
      payload: { ok, checks, error, webviewWebGpuExposed: 'gpu' in navigator },
    });
  }
}
