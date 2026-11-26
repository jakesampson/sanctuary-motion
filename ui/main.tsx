import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { open, save } from '@tauri-apps/plugin-dialog';
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';
import { catalog, looks } from './looks';
import { finishes } from './finishes';
import { ColorPanel, MotionPanel, TunePanel, RangeControl, ResetControl, percent, initialColor, initialAnimation, type RGB, type ColorSettings, type AnimationSettings } from './controls';
import { TextPanel, initialText, type TextSettings } from './text';
import { defaultLookTune, defaultFinishTune, lookTune, finishTune, type TuneSettings } from './tune';

const editorSteps = ['Look', 'Finish', 'Color', 'Motion', 'Text', 'Screen'] as const;

type Palette = [RGB, RGB, RGB];
type Scene = {
  version: 1;
  look: number;
  finish: number;
  color: ColorSettings;
  animation: AnimationSettings;
  text: TextSettings;
  lookTune: TuneSettings;
  finishTune: TuneSettings;
  seed: number;
  motion: number;
  intensity: number;
  colors: Palette;
  width: number;
  height: number;
  fps: number;
  duration: number;
};

const thumbnailPalettes: { name: string; colors: Palette }[] = [
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
  ['Triple wide · 48:9', 5760, 1080],
  ['Portrait · 9:16', 1080, 1920],
  ['Square · 1:1', 1080, 1080],
] as const;
const initial: Scene = {
  version: 1, look: 0, finish: 0, color: initialColor, animation: initialAnimation, text: initialText,
  lookTune: defaultLookTune(0), finishTune: defaultFinishTune(0),
  seed: 1, motion: 1, intensity: 0.75,
  colors: thumbnailPalettes[0].colors, width: 1920, height: 1080, fps: 30, duration: 15,
};
const projectFilter = { name: 'Sanctuary Motion project', extensions: ['sanctuary'] };

function draw(canvas: HTMLCanvasElement, bytes: ArrayBuffer, width: number, height: number) {
  if (canvas.width !== width) canvas.width = width;
  if (canvas.height !== height) canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Canvas rendering is unavailable.');
  context.putImageData(new ImageData(new Uint8ClampedArray(bytes), width, height), 0, 0);
}

function Thumbnail({ look, finish, text }: { look: number; finish: number; text?: TextSettings }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const node = canvas.current;
    if (!node) return;
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) setVisible(true);
    }, { rootMargin: '160px' });
    observer.observe(node);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    if (!visible) return;
    let ignore = false;
    const scene = {
      ...initial, look, finish,
      colors: thumbnailPalettes[look % thumbnailPalettes.length].colors,
      text: text ?? initial.text,
    };
    invoke<ArrayBuffer>('preview_frame', { scene, phase: 0.21, width: 144, height: 81 })
      .then(bytes => { if (!ignore && canvas.current) draw(canvas.current, bytes, 144, 81); })
      .catch(() => { /* The main preview surfaces renderer errors. */ });
    return () => { ignore = true; };
  }, [visible, look, finish, text?.treatment, text?.mode, text?.content, text?.enabled]);
  return <canvas ref={canvas} aria-hidden="true" />;
}

function EffectGallery({ surface, selected, onSelect }: {
  surface: boolean; selected: number; onSelect: (id: number) => void;
}) {
  const entries = surface ? finishes : catalog;
  const itemName = surface ? 'finishes' : 'looks';
  const categories = ['All', ...new Set(entries.map(([, category]) => category))];
  const [category, setCategory] = useState('All');
  const [search, setSearch] = useState('');
  const normalized = (value: string) => value.toLocaleLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
  const query = normalized(search.trim());
  const matches = entries.map(([name, group], id) => ({ name, group, id })).filter(({ name, group }) =>
    (category === 'All' || group === category) && normalized(`${name} ${group}`).includes(query));
  return <div className="gallery">
    <div className="card-heading"><h2>{surface ? 'Surface finish' : 'Background look'}</h2><span className="size">{entries[selected][0]}</span></div>
    <div className="look-filters">
      <label className="field">Collection
        <select value={category} onChange={event => setCategory(event.target.value)}>
          {categories.map(group => <option key={group}>{group}</option>)}
        </select>
      </label>
      <label className="field">Search {itemName}
        <input type="search" value={search} onChange={event => setSearch(event.target.value)} />
      </label>
    </div>
    <div className="looks" aria-label={itemName}>
      {matches.map(({ name, id }) =>
        <button className="look" key={id} aria-pressed={id === selected} onClick={() => onSelect(id)}>
          <Thumbnail look={surface ? 20 : id} finish={surface ? id : 0} /><span>{name}</span>
        </button>)}
    </div>
    {matches.length === 0 && <p className="gallery-status" role="status">No matching {itemName}.</p>}
  </div>;
}

function Preview({ scene, lyrics, playing, textPlaying, textReset, overlayFit, overlayRevision }: {
  scene: Scene; lyrics: boolean; playing: boolean; textPlaying: boolean; textReset: number;
  overlayFit: boolean | null; overlayRevision: number;
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const surface = useRef<HTMLDivElement>(null);
  const job = useRef({ scene, playing, textPlaying, textReset, overlayFit, overlayRevision });
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    job.current = { scene, playing, textPlaying, textReset, overlayFit, overlayRevision };
  }, [scene, playing, textPlaying, textReset, overlayFit, overlayRevision]);
  useEffect(() => {
    let stopped = false;
    let timer = 0;
    let phase = 0;
    let textPhase = 0;
    let lastTextReset = 0;
    let last = performance.now();
    let drawn: Scene | undefined;
    let drawnSize = '';
    let drawnOverlay = -1;
    let drawnFit: boolean | null = null;
    async function tick() {
      const { scene, playing, textPlaying, textReset, overlayFit, overlayRevision } = job.current;
      const now = performance.now();
      const elapsed = (now - last) / (scene.duration * 1000);
      if (playing) phase = (phase + elapsed) % 1;
      const textChanged = lastTextReset !== textReset;
      if (textChanged) textPhase = 0;
      else if (playing && textPlaying) textPhase = (textPhase + elapsed) % 1;
      lastTextReset = textReset;
      last = now;
      const ratio = scene.width / scene.height;
      const box = surface.current?.getBoundingClientRect();
      const width = Math.max(1, Math.round(Math.min(800, (box?.width ?? 600) * devicePixelRatio)));
      const height = Math.max(1, Math.round(Math.min(800, width / ratio)));
      const renderWidth = Math.max(1, Math.round(Math.min(width, height * ratio)));
      const size = `${renderWidth}x${height}`;
      if (playing || textChanged || scene !== drawn || size !== drawnSize || overlayRevision !== drawnOverlay || overlayFit !== drawnFit) {
        try {
          const bytes = await invoke<ArrayBuffer>('preview_frame', { scene, phase, textPhase, overlayFit, width: renderWidth, height });
          if (stopped) return;
          if (canvas.current) draw(canvas.current, bytes, renderWidth, height);
          drawn = scene;
          drawnSize = size;
          drawnOverlay = overlayRevision;
          drawnFit = overlayFit;
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
  const [step, setStep] = useState(0);
  const [lyrics, setLyrics] = useState(false);
  const [playing, setPlaying] = useState(true);
  const [textPlaying, setTextPlaying] = useState(true);
  const [textReset, setTextReset] = useState(0);
  const [overlayName, setOverlayName] = useState('');
  const [overlayFit, setOverlayFit] = useState(false);
  const [overlayRevision, setOverlayRevision] = useState(0);
  const [overlayBusy, setOverlayBusy] = useState(false);
  const [includeText, setIncludeText] = useState(false);
  const [includeOverlay, setIncludeOverlay] = useState(false);
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
      setTextReset(value => value + 1);
      setIncludeText(false);
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
      await invoke('export_scene', { request: {
        scene: { ...current, text: { ...current.text, enabled: current.text.enabled && includeText } },
        path, format, overlayFit: overlayName && includeOverlay ? overlayFit : null,
      } });
      setNotice(`Exported ${filename(path)}.`);
    } catch (cause) {
      if (String(cause) === 'Export cancelled.') setNotice('Export cancelled.');
      else setError(String(cause));
    } finally { setBusy(false); setCancelling(false); }
  }

  async function chooseOverlay() {
    setOverlayBusy(true);
    setError('');
    try {
      const path = await open({ multiple: false, directory: false, filters: [{ name: 'Overlay image', extensions: ['png', 'jpg', 'jpeg', 'svg'] }] });
      if (!path) return;
      await invoke('select_overlay', { path });
      setOverlayName(filename(path));
      setOverlayRevision(value => value + 1);
    } catch (cause) { setError(String(cause)); }
    finally { setOverlayBusy(false); }
  }

  async function removeOverlay() {
    setOverlayBusy(true);
    setError('');
    try {
      await invoke('clear_overlay');
      setOverlayName('');
      setIncludeOverlay(false);
      setOverlayRevision(value => value + 1);
    } catch (cause) { setError(String(cause)); }
    finally { setOverlayBusy(false); }
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
      <nav className="editor-steps" aria-label="Editor steps">
        {editorSteps.map((label, index) =>
          <button key={label} aria-current={step === index ? 'step' : undefined} onClick={() => setStep(index)}>
            <span aria-hidden="true">{String(index + 1).padStart(2, '0')}</span> {label}
          </button>)}
      </nav>
      <section className="studio" aria-label="Preview and looks">
        <div className="card stage">
          <div className="card-heading"><h2>Preview</h2><span className="size">{scene.width} × {scene.height}</span></div>
          <Preview scene={scene} lyrics={lyrics} playing={playing} textPlaying={textPlaying} textReset={textReset}
            overlayFit={overlayName ? overlayFit : null} overlayRevision={overlayRevision} />
          <div className="transport">
            <button onClick={() => setPlaying(!playing)}>{playing ? 'Pause' : 'Play'}</button>
            <label className="toggle"><input type="checkbox" checked={lyrics} onChange={event => setLyrics(event.target.checked)} /> Preview lyrics</label>
          </div>
        </div>
        <section className="card editor" aria-label="Background editor">
          {step === 0 && <>
            <EffectGallery key="looks" surface={false} selected={scene.look}
              onSelect={id => setScene(prev => ({ ...prev, look: id, lookTune: defaultLookTune(id) }))} />
            <TunePanel title={`${looks[scene.look]} settings`} spec={lookTune[scene.look]} value={scene.lookTune}
              onChange={value => update('lookTune', value)} />
          </>}
          {step === 1 && <>
            <EffectGallery key="finishes" surface selected={scene.finish}
              onSelect={id => setScene(prev => ({ ...prev, finish: id, finishTune: defaultFinishTune(id) }))} />
            <TunePanel title={`${finishes[scene.finish][0]} settings`} spec={finishTune[scene.finish]} value={scene.finishTune}
              onChange={value => update('finishTune', value)} />
          </>}
          {step === 2 && <ColorPanel colors={scene.colors} color={scene.color}
            onChange={(colors, color) => setScene(prev => ({ ...prev, colors, color }))} />}
          {step === 3 && <MotionPanel animation={scene.animation} duration={scene.duration} motion={scene.motion}
            onAnimation={value => update('animation', value)} onDuration={value => update('duration', value)}
            onMotion={value => update('motion', value)} />}
          {step === 4 && <TextPanel look={scene.look} finish={scene.finish} Thumbnail={Thumbnail} text={scene.text}
            onChange={value => update('text', value)} playing={textPlaying}
            onPlayback={() => setTextPlaying(value => !value)} onRestart={() => setTextReset(value => value + 1)} />}
          {step === 5 && <div className="step-content">
            <div className="card-heading"><h2>Screen and export</h2></div>
            <label className="field">Screen size
              <select value={custom || screen < 0 ? 'custom' : String(screen)} onChange={event => chooseScreen(event.target.value)}>
                {screens.map(([label, width, height], index) => <option key={label} value={index}>{label} · {width} × {height}</option>)}
                <option value="custom">Custom size</option>
              </select>
            </label>
            {(custom || screen < 0) && <CustomSize key={`${scene.width}x${scene.height}`} width={scene.width} height={scene.height}
              onApply={(width, height) => setScene(prev => ({ ...prev, width, height }))} />}
            <fieldset><legend>Image overlay</legend>
              <div className="editor-actions">
                <button disabled={overlayBusy} onClick={chooseOverlay}>Choose image</button>
                {overlayName && <button disabled={overlayBusy} onClick={removeOverlay}>Remove</button>}
              </div>
              <p className="gallery-status overlay-name">{overlayName || 'PNG, JPEG or vector SVG. This image is kept for this session.'}</p>
              {overlayName && <div className="editor-actions">
                <button aria-pressed={!overlayFit} onClick={() => setOverlayFit(false)}>Fill</button>
                <button aria-pressed={overlayFit} onClick={() => setOverlayFit(true)}>Fit</button>
              </div>}
            </fieldset>
            <div className="editor-actions">
              <button className="primary" disabled={busy || overlayBusy}
                onClick={() => { if (odd) setFormat('png'); dialog.current?.showModal(); }}>Export background</button>
            </div>
          </div>}
          {step < 5 && <div className="step-footer">
            <button onClick={() => setStep(step + 1)}>Continue to {['Finish', 'Color', 'Motion', 'Text', 'Screen'][step]}</button>
          </div>}
        </section>
      </section>
      <aside className="card inspector" aria-label="Background settings">
        <div className="card-heading"><h2>Settings</h2></div>
        <details><summary>Fine tune<ResetControl name="fine tune" onReset={() => update('intensity', 0.75)} /></summary>
          <RangeControl name="Intensity" value={scene.intensity} min={0} max={1} step={0.01} defaultValue={0.75}
            label={percent(scene.intensity)} onChange={intensity => update('intensity', intensity)} />
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
          </> : <button onClick={() => setStep(5)}>Screen and export</button>}
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
      {scene.text.enabled && scene.text.content.trim() && <label className="toggle">
        <input type="checkbox" checked={includeText} onChange={event => setIncludeText(event.target.checked)} /> Include text layer
      </label>}
      {overlayName && <label className="toggle">
        <input type="checkbox" checked={includeOverlay} onChange={event => setIncludeOverlay(event.target.checked)} /> Include image overlay
      </label>}
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
