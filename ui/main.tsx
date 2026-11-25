import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { open, save } from '@tauri-apps/plugin-dialog';
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';

type RGB = [number, number, number];
type Palette = [RGB, RGB, RGB];
type Scene = {
  version: 1;
  look: number;
  seed: number;
  motion: number;
  intensity: number;
  colors: Palette;
  width: number;
  height: number;
  fps: number;
  duration: number;
};

const looks = ['Aurora', 'Silk', 'Bokeh', 'Dust', 'Fog', 'Light Rays'];
const palettes: { name: string; colors: Palette }[] = [
  { name: 'Sea Glass', colors: [[8, 12, 27], [39, 96, 132], [116, 225, 186]] },
  { name: 'Ember', colors: [[21, 11, 20], [134, 45, 47], [248, 169, 90]] },
  { name: 'Violet', colors: [[14, 9, 30], [87, 55, 148], [200, 157, 247]] },
  { name: 'Glacier', colors: [[10, 18, 31], [48, 100, 181], [141, 212, 244]] },
  { name: 'Candlelight', colors: [[20, 16, 25], [136, 94, 57], [244, 217, 152]] },
];
const screens = [
  ['HD · 16:9', 1920, 1080],
  ['4K · 16:9', 3840, 2160],
  ['Cinema · 21:9', 2520, 1080],
  ['Ultrawide · 32:9', 3840, 1080],
  ['Portrait · 9:16', 1080, 1920],
  ['Square · 1:1', 1080, 1080],
] as const;
const initial: Scene = {
  version: 1, look: 0, seed: 1, motion: 1, intensity: 0.75,
  colors: palettes[0].colors, width: 1920, height: 1080, fps: 30, duration: 15,
};
const projectFilter = { name: 'Sanctuary Motion project', extensions: ['sanctuary'] };
const toHex = (rgb: RGB) => '#' + rgb.map(value => value.toString(16).padStart(2, '0')).join('');
const fromHex = (hex: string): RGB => [1, 3, 5].map(i => parseInt(hex.substring(i, i + 2), 16)) as RGB;

function draw(canvas: HTMLCanvasElement, bytes: ArrayBuffer, width: number, height: number) {
  if (canvas.width !== width) canvas.width = width;
  if (canvas.height !== height) canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Canvas rendering is unavailable.');
  context.putImageData(new ImageData(new Uint8ClampedArray(bytes), width, height), 0, 0);
}

function Thumbnail({ look }: { look: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    let ignore = false;
    const scene = { ...initial, look, colors: palettes[look % palettes.length].colors };
    invoke<ArrayBuffer>('preview_frame', { scene, phase: 0.21, width: 144, height: 81 })
      .then(bytes => { if (!ignore && canvas.current) draw(canvas.current, bytes, 144, 81); })
      .catch(() => { /* The main preview surfaces renderer errors. */ });
    return () => { ignore = true; };
  }, [look]);
  return <canvas ref={canvas} aria-hidden="true" />;
}

function Preview({ scene, lyrics, playing }: { scene: Scene; lyrics: boolean; playing: boolean }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const surface = useRef<HTMLDivElement>(null);
  const job = useRef({ scene, playing });
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => { job.current = { scene, playing }; }, [scene, playing]);
  useEffect(() => {
    let stopped = false;
    let timer = 0;
    let phase = 0;
    let last = performance.now();
    let drawn: Scene | undefined;
    let drawnSize = '';
    async function tick() {
      const { scene, playing } = job.current;
      const now = performance.now();
      if (playing) phase = (phase + (now - last) / (scene.duration * 1000)) % 1;
      last = now;
      const ratio = scene.width / scene.height;
      const box = surface.current?.getBoundingClientRect();
      const width = Math.max(1, Math.round(Math.min(800, (box?.width ?? 600) * devicePixelRatio)));
      const height = Math.max(1, Math.round(Math.min(800, width / ratio)));
      const renderWidth = Math.max(1, Math.round(Math.min(width, height * ratio)));
      const size = `${renderWidth}x${height}`;
      if (playing || scene !== drawn || size !== drawnSize) {
        try {
          const bytes = await invoke<ArrayBuffer>('preview_frame', { scene, phase, width: renderWidth, height });
          if (stopped) return;
          if (canvas.current) draw(canvas.current, bytes, renderWidth, height);
          drawn = scene;
          drawnSize = size;
        } catch (cause) {
          if (!stopped) setError(String(cause));
          return;
        }
      }
      if (!stopped) timer = window.setTimeout(tick, Math.max(0, 1000 / 30 - (performance.now() - now)));
    }
    void tick();
    return () => { stopped = true; window.clearTimeout(timer); };
  }, [attempt]);
  return <div className="preview-well">
    <div ref={surface} className="preview-surface" style={{ '--aspect': scene.width / scene.height } as CSSProperties}>
      <canvas ref={canvas} aria-label={`Animated ${looks[scene.look]} background`} />
      {lyrics && <div className="lyrics">Amazing grace<br />How sweet the sound</div>}
    </div>
    {error && <div className="preview-error" role="alert"><p>{error}</p>
      <button onClick={() => { setError(''); setAttempt(attempt + 1); }}>Retry preview</button>
    </div>}
  </div>;
}

function CustomSize({ width, height, onApply }: {
  width: number; height: number; onApply: (width: number, height: number) => void;
}) {
  const [draft, setDraft] = useState({ width: String(width), height: String(height) });
  const nextWidth = Number(draft.width);
  const nextHeight = Number(draft.height);
  const dirty = draft.width !== String(width) || draft.height !== String(height);
  const valid = [nextWidth, nextHeight].every(value => Number.isInteger(value) && value >= 1 && value <= 8192)
    && nextWidth * nextHeight <= 16_777_216;
  return <form className="custom-size" onSubmit={event => {
    event.preventDefault();
    if (valid) onApply(nextWidth, nextHeight);
  }}>
    <div className="dimensions">
      <label className="field">Width<input type="number" min="1" max="8192" required value={draft.width}
        onChange={event => setDraft({ ...draft, width: event.target.value })} /></label>
      <label className="field">Height<input type="number" min="1" max="8192" required value={draft.height}
        onChange={event => setDraft({ ...draft, height: event.target.value })} /></label>
    </div>
    {dirty && !valid && <p className="message error">Enter whole pixels, up to 8192 per side and 16 megapixels total.</p>}
    <button type="submit" disabled={!valid || !dirty}>Apply custom size</button>
  </form>;
}

function App() {
  const [scene, setScene] = useState(initial);
  const [lyrics, setLyrics] = useState(false);
  const [playing, setPlaying] = useState(true);
  const [custom, setCustom] = useState(false);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [progress, setProgress] = useState(0);
  const [format, setFormat] = useState<'mp4' | 'png'>('mp4');
  const [name, setName] = useState('Untitled project');
  const dialog = useRef<HTMLDialogElement>(null);
  const update = <K extends keyof Scene>(key: K, value: Scene[K]) => setScene(prev => ({ ...prev, [key]: value }));
  const filename = (path: string) => path.split(/[/\\]/).at(-1) ?? path;

  useEffect(() => {
    const subscription = listen<number>('export-progress', event => setProgress(event.payload));
    return () => { void subscription.then(unlisten => unlisten()); };
  }, []);

  async function openProject() {
    setError('');
    setNotice('');
    try {
      const path = await open({ multiple: false, directory: false, filters: [projectFilter] });
      if (!path) return;
      const loaded = await invoke<Scene>('open_project', { path });
      setScene(loaded);
      setCustom(!screens.some(([, w, h]) => loaded.width === w && loaded.height === h));
      setName(filename(path).replace(/\.sanctuary$/i, ''));
      setNotice('Project opened.');
    } catch (cause) { setError(String(cause)); }
  }

  async function saveProject() {
    setError('');
    setNotice('');
    try {
      const path = await save({ defaultPath: `${name}.sanctuary`, filters: [projectFilter] });
      if (!path) return;
      await invoke('save_project', { path, scene });
      setName(filename(path).replace(/\.sanctuary$/i, ''));
      setNotice('Project saved.');
    } catch (cause) { setError(String(cause)); }
  }

  async function exportFile() {
    if (busy) return;
    setBusy(true);
    setCancelling(false);
    setProgress(0);
    setError('');
    setNotice('');
    const current = scene;
    try {
      const path = await save({
        defaultPath: `${looks[current.look].toLowerCase().replaceAll(' ', '-')}-${current.width}x${current.height}.${format}`,
        filters: [{ name: format === 'mp4' ? 'MP4 video' : 'PNG image', extensions: [format] }],
      });
      if (!path) return;
      dialog.current?.close();
      await invoke('export_scene', { request: { scene: current, path, format } });
      setNotice(`Exported ${filename(path)}.`);
    } catch (cause) {
      if (String(cause) === 'Export cancelled.') setNotice('Export cancelled.');
      else setError(String(cause));
    } finally { setBusy(false); setCancelling(false); }
  }

  function chooseScreen(value: string) {
    setCustom(value === 'custom');
    const selected = screens[Number(value)];
    if (selected) setScene(prev => ({ ...prev, width: selected[1], height: selected[2] }));
  }
  const screen = screens.findIndex(([, width, height]) => width === scene.width && height === scene.height);
  const odd = scene.width % 2 !== 0 || scene.height % 2 !== 0;
  return <>
    <header className="topbar">
      <div className="identity"><span className="mark" aria-hidden="true">✳</span>
        <div><h1>Sanctuary Motion</h1><p>{name}</p></div>
      </div>
      <div className="top-actions">
        <button onClick={openProject}>Open<span className="wide"> project</span></button>
        <button onClick={saveProject}>Save<span className="wide"> project</span></button>
      </div>
    </header>
    <main>
      <section className="studio" aria-label="Preview and looks">
        <div className="card stage">
          <div className="card-heading"><h2>Preview</h2><span className="size">{scene.width} × {scene.height}</span></div>
          <Preview scene={scene} lyrics={lyrics} playing={playing} />
          <div className="transport">
            <button onClick={() => setPlaying(!playing)}>{playing ? 'Pause' : 'Play'}</button>
            <label className="toggle"><input type="checkbox" checked={lyrics} onChange={event => setLyrics(event.target.checked)} /> Preview lyrics</label>
          </div>
        </div>
        <div className="card gallery">
          <div className="card-heading"><h2>Looks</h2></div>
          <div className="looks" aria-label="Background looks">
            {looks.map((look, index) => <button className="look" key={look} aria-pressed={index === scene.look} onClick={() => update('look', index)}>
              <Thumbnail look={index} /><span>{look}</span>
            </button>)}
          </div>
        </div>
      </section>
      <aside className="card inspector" aria-label="Background settings">
        <div className="card-heading"><h2>Settings</h2></div>
        <fieldset><legend>Palette</legend>
          <div className="palettes">
            {palettes.map(palette => <button key={palette.name} type="button" title={palette.name}
              aria-label={palette.name} aria-pressed={JSON.stringify(palette.colors) === JSON.stringify(scene.colors)}
              onClick={() => update('colors', palette.colors)}
              style={{ background: `linear-gradient(135deg,${palette.colors.map(toHex).join(',')})` }} />)}
          </div>
        </fieldset>
        <fieldset><legend>Motion</legend>
          <div className="segments">{['Quiet', 'Gentle', 'Full'].map((label, index) =>
            <button key={label} aria-pressed={scene.motion === index} onClick={() => update('motion', index)}>{label}</button>)}</div>
        </fieldset>
        <label className="field">Screen
          <select value={custom || screen < 0 ? 'custom' : String(screen)} onChange={event => chooseScreen(event.target.value)}>
            {screens.map(([label, width, height], index) => <option key={label} value={index}>{label} · {width} × {height}</option>)}
            <option value="custom">Custom size</option>
          </select>
        </label>
        {(custom || screen < 0) && <CustomSize key={`${scene.width}x${scene.height}`} width={scene.width} height={scene.height}
          onApply={(width, height) => setScene(prev => ({ ...prev, width, height }))} />}
        <details><summary>Fine tune</summary>
          <fieldset><legend>Custom colors</legend><div className="custom-colors">
            {scene.colors.map((color, index) => <input key={index} type="color" aria-label={['Base color', 'Midtone color', 'Highlight color'][index]}
              value={toHex(color)} onChange={event => {
                const next = [...scene.colors] as Palette;
                next[index] = fromHex(event.target.value);
                update('colors', next);
              }} />)}
          </div></fieldset>
          <label className="field">Intensity <input type="range" min="0" max="1" step="0.01" value={scene.intensity}
            onChange={event => update('intensity', event.target.valueAsNumber)} /></label>
          <button onClick={() => update('seed', crypto.getRandomValues(new Uint32Array(1))[0])}>Try another variation</button>
        </details>
        <div className="export-area">
          {error && <p className="message error" role="alert">{error}</p>}
          {notice && <p className="message" role="status">{notice}</p>}
          {busy ? <>
            <progress value={progress} max={1} aria-label="Export progress" />
            <button disabled={cancelling} onClick={async () => {
              setCancelling(true);
              try { await invoke('cancel_export'); } catch (cause) { setError(String(cause)); setCancelling(false); }
            }}>{cancelling ? 'Cancelling…' : 'Cancel export'}</button>
          </> : <button className="primary" onClick={() => { if (odd) setFormat('png'); dialog.current?.showModal(); }}>Export background</button>}
        </div>
      </aside>
    </main>
    <dialog ref={dialog} onCancel={event => { if (busy) event.preventDefault(); }}>
      <h2>Export background</h2>
      <p>{looks[scene.look]} · {scene.width} × {scene.height}</p>
      <label className="field">Format
        <select value={format} disabled={busy} onChange={event => setFormat(event.target.value === 'png' ? 'png' : 'mp4')}>
          <option value="mp4" disabled={odd}>MP4 · Motion loop</option><option value="png">PNG · Still image</option>
        </select>
      </label>
      {odd && <p>MP4 needs even pixel dimensions. PNG preserves this size.</p>}
      {format === 'mp4' && <div className="dimensions">
        <label className="field">Duration<select disabled={busy} value={scene.duration} onChange={event => update('duration', Number(event.target.value))}>
          {Array.from(new Set([10, 15, 30, 60, scene.duration])).sort((a, b) => a - b).map(value => <option key={value} value={value}>{value} seconds</option>)}
        </select></label>
        <label className="field">Frame rate<select disabled={busy} value={scene.fps} onChange={event => update('fps', Number(event.target.value))}>
          {[24, 25, 30, 50, 60].map(value => <option key={value} value={value}>{value} fps</option>)}
        </select></label>
      </div>}
      <div className="dialog-actions"><button disabled={busy} onClick={() => dialog.current?.close()}>Close</button>
        <button className="primary" disabled={busy} onClick={exportFile}>Choose destination</button></div>
    </dialog>
  </>;
}

createRoot(document.getElementById('root')!).render(<App />);
