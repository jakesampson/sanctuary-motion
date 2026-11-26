import { useState } from 'react';

export type RGB = [number, number, number];
type Palette = [RGB, RGB, RGB];
type Ramp = [RGB, RGB, RGB, RGB];

export type ColorSettings = {
  mode: number; glow: RGB | null; tint: RGB; amount: number; gradient: Ramp; layout: number;
};
export type AnimationSettings = {
  cycles: number; movement: number; scale: number; shiftX: number; shiftY: number;
  stopFps: number; ease: number;
};

const fromHex = (value: string): RGB => [
  parseInt(value.slice(1, 3), 16), parseInt(value.slice(3, 5), 16), parseInt(value.slice(5, 7), 16),
];
const hex = (rgb: RGB) => '#' + rgb.map(value => value.toString(16).padStart(2, '0')).join('');
const ramp = (a: string, b: string, c: string, d: string): Ramp => [fromHex(a), fromHex(b), fromHex(c), fromHex(d)];

export const initialColor: ColorSettings = {
  mode: 0, glow: null, tint: [255, 174, 110], amount: 1,
  gradient: [[168, 41, 113], [112, 62, 172], [54, 120, 204], [132, 225, 241]], layout: 0,
};
export const initialAnimation: AnimationSettings = {
  cycles: 1, movement: 1, scale: 1, shiftX: 0, shiftY: 0, stopFps: 0, ease: 0,
};

const palettes: [string, Ramp][] = [
  ['Sea Glass', ramp('#080c1b','#276084','#4da8af','#74e1ba')],
  ['Copper', ramp('#150b14','#862d2f','#df693c','#f8a95a')],
  ['Cobalt', ramp('#01040c','#0b286e','#2979e6','#aad2ff')],
  ['Fern', ramp('#07100d','#215138','#55ab6c','#c6f1a9')],
  ['Violet', ramp('#0e091e','#573794','#9582df','#c89df7')],
  ['Crimson', ramp('#18080d','#781c34','#dc464c','#ffb6a0')],
  ['Candlelight', ramp('#141019','#885e39','#db9e55','#f4d998')],
  ['Tidal', ramp('#081622','#245c7c','#43a7b9','#b8f1ee')],
  ['Rose', ramp('#1b0c19','#783951','#d77391','#ffc7d7')],
  ['Dusk', ramp('#1b0c22','#784263','#da6d58','#ffbd82')],
  ['Silver', ramp('#090d18','#424958','#8f9ba8','#e5eef1')],
  ['Ice', ramp('#0a121f','#3064b5','#6ab3e4','#dff6ff')],
];
const gradientPresets: [string, Ramp][] = [
  ['Orchid to Ice', initialColor.gradient],
  ['Blue Hour', ramp('#0b1749','#245ac3','#5da3f5','#d5f0ff')],
  ['Embers', ramp('#5e1f29','#a43728','#ef792f','#ffd8a2')],
  ['Emerald', ramp('#0c352b','#268265','#55c190','#cdfbe4')],
  ['Violet to Rose', ramp('#34195d','#6932aa','#db4fa0','#ffcde5')],
  ['Gold', ramp('#4e3521','#91613c','#ddab60','#fff0c7')],
  ['Teal to Apricot', ramp('#144a5d','#31a3a6','#ef8a5c','#ffd9bc')],
  ['Sunset', ramp('#321e58','#914a90','#ec7559','#ffde8d')],
  ['Ice', ramp('#205072','#5493b2','#a8d6ee','#e5f9ff')],
  ['Lime', ramp('#12413d','#34816d','#a1d13f','#e5ffc2')],
  ['Rose Gold', ramp('#512b46','#a85863','#ea9e86','#fff1e4')],
  ['Mono', ramp('#30343e','#565f6e','#a8b1bd','#ffffff')],
];
const tints = ['#ffae6e','#ffd479','#f88172','#ee659d','#b97df4','#728df6','#5fd2de','#91df9d','#ffffff'];
const storageKey = 'sanctuary-motion.saved-palettes';
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

function readPalettes(): Ramp[] {
  try {
    const stored: unknown = JSON.parse(localStorage.getItem(storageKey) ?? '[]');
    if (!Array.isArray(stored)) return [];
    return stored.filter((row): row is Ramp => Array.isArray(row) && row.length === 4 &&
      row.every(rgb => Array.isArray(rgb) && rgb.length === 3 &&
        rgb.every(value => Number.isInteger(value) && value >= 0 && value <= 255))).slice(0, 12);
  } catch { return []; }
}

function ColorField({ name, value, onChange }: { name: string; value: RGB; onChange: (value: RGB) => void }) {
  const current = hex(value);
  function commit(input: HTMLInputElement) {
    const candidate = '#' + input.value.trim().replace(/^#/, '');
    if (/^#[\da-f]{6}$/i.test(candidate)) onChange(fromHex(candidate));
    else input.value = current;
  }
  return <div className="color-field">
    <label>{name}<input type="color" value={current} onChange={event => onChange(fromHex(event.target.value))} /></label>
    <input key={current} aria-label={name + ' hex'} defaultValue={current} maxLength={7} spellCheck={false}
      onBlur={event => commit(event.currentTarget)}
      onKeyDown={event => { if (event.key === 'Enter') event.currentTarget.blur(); }} />
  </div>;
}

function RampChoices({ entries, active, select }: { entries: [string, Ramp][]; active: Ramp; select: (colors: Ramp) => void }) {
  return <div className="ramp-choices">
    {entries.map(([name, colors]) => <button key={name} aria-pressed={same(colors, active)} onClick={() => select(colors)}>
      <span className="ramp-swatch" style={{ background: 'linear-gradient(90deg,' + colors.map(hex).join(',') + ')' }} />
      {name}
    </button>)}
  </div>;
}

function RangeControl({ name, value, min, max, step = 1, label, onChange }: {
  name: string; value: number; min: number; max: number; step?: number; label: string; onChange: (value: number) => void;
}) {
  return <label className="range-control">
    <span>{name}<output aria-hidden="true">{label}</output></span>
    <input aria-label={name} aria-valuetext={label} type="range" value={value} min={min} max={max} step={step}
      onChange={event => onChange(event.target.valueAsNumber)} />
  </label>;
}

const percent = (value: number) => Math.round(value * 100) + '%';

export function ColorPanel({ colors, color, onChange }: {
  colors: Palette; color: ColorSettings; onChange: (colors: Palette, color: ColorSettings) => void;
}) {
  const [saved, setSaved] = useState(readPalettes);
  const [status, setStatus] = useState('');
  const active: Ramp = [colors[0], colors[1], color.glow ?? colors[2], colors[2]];
  const update = (settings: Partial<ColorSettings>) => onChange(colors, { ...color, ...settings });
  const select = ([shadow, mid, glow, highlight]: Ramp) => onChange([shadow, mid, highlight], { ...color, glow });
  const save = () => {
    const next = [...saved, active];
    try {
      localStorage.setItem(storageKey, JSON.stringify(next));
      setSaved(next);
      setStatus('Palette saved on this computer.');
    } catch { setStatus('Could not save this palette.'); }
  };
  return <div className="step-content">
    <div className="card-heading"><h2>Color</h2></div>
    <div className="segments" aria-label="Color mode">
      {['Palette', 'Tint', 'Gradient map'].map((name, mode) => <button key={name}
        aria-pressed={color.mode === mode} onClick={() => update({ mode })}>{name}</button>)}
    </div>
    {color.mode === 0 && <>
      <RampChoices entries={palettes} active={active} select={select} />
      <div className="color-fields">
        {['Shadow', 'Midtone', 'Glow', 'Highlight'].map((name, index) =>
          <ColorField key={name} name={name} value={active[index]} onChange={value => {
            const next: Ramp = [...active];
            next[index] = value;
            if (index === 2 || color.glow) select(next);
            else onChange([next[0], next[1], next[3]], color);
          }} />)}
      </div>
      {saved.length > 0 && <RampChoices entries={saved.map((value, i) => ['Saved ' + (i + 1), value])} active={active} select={select} />}
      <div><button onClick={save} disabled={saved.length >= 12 || saved.some(value => same(value, active))}>Save palette locally</button>
        {status && <p className="gallery-status" role="status">{status}</p>}</div>
    </>}
    {color.mode === 1 && <>
      <div className="palettes">
        {tints.map(value => <button key={value} title={value} aria-label={'Tint ' + value}
          aria-pressed={hex(color.tint) === value} onClick={() => update({ tint: fromHex(value) })}
          style={{ background: value }} />)}
      </div>
      <div className="color-fields"><ColorField name="Custom tint" value={color.tint} onChange={tint => update({ tint })} /></div>
      <RangeControl name="Tint amount" value={color.amount} min={0} max={1} step={0.01} label={percent(color.amount)}
        onChange={amount => update({ amount })} />
    </>}
    {color.mode === 2 && <>
      <RampChoices entries={gradientPresets} active={color.gradient} select={gradient => update({ gradient })} />
      <label className="field">Gradient layout<select value={color.layout} onChange={event => update({ layout: Number(event.target.value) })}>
        {['Split', 'Radial', 'By brightness', 'Bands', 'Clouds'].map((name, index) => <option key={name} value={index}>{name}</option>)}
      </select></label>
      <div className="color-fields">
        {color.gradient.map((value, index) => <ColorField key={index} name={'Stop ' + (index + 1)} value={value} onChange={replacement => {
          const gradient: Ramp = [...color.gradient];
          gradient[index] = replacement;
          update({ gradient });
        }} />)}
      </div>
    </>}
  </div>;
}

export function MotionPanel({ animation, duration, motion, onAnimation, onDuration, onMotion }: {
  animation: AnimationSettings; duration: number; motion: number;
  onAnimation: (animation: AnimationSettings) => void; onDuration: (duration: number) => void; onMotion: (motion: number) => void;
}) {
  const update = (value: Partial<AnimationSettings>) => onAnimation({ ...animation, ...value });
  return <div className="step-content">
    <div className="card-heading"><h2>Motion</h2></div>
    <div className="segments" aria-label="Motion preset">
      {['Quiet', 'Gentle', 'Full'].map((label, index) => <button key={label} aria-pressed={motion === index} onClick={() => onMotion(index)}>{label}</button>)}
    </div>
    <RangeControl name="Speed" value={animation.cycles} min={0} max={4}
      label={animation.cycles === 0 ? 'Still' : animation.cycles + (animation.cycles === 1 ? ' cycle per loop' : ' cycles per loop')}
      onChange={cycles => update({ cycles })} />
    <RangeControl name="Duration" value={duration} min={1} max={60} label={duration + ' s'} onChange={onDuration} />
    <RangeControl name="Movement" value={animation.movement} min={0} max={2} step={0.01} label={percent(animation.movement)}
      onChange={movement => update({ movement })} />
    <details><summary>Framing and timing</summary>
      <RangeControl name="Scale" value={animation.scale} min={0.5} max={3} step={0.01} label={percent(animation.scale)}
        onChange={scale => update({ scale })} />
      <RangeControl name="Horizontal shift" value={animation.shiftX} min={-0.5} max={0.5} step={0.01}
        label={animation.shiftX === 0 ? 'Centered' : percent(animation.shiftX)} onChange={shiftX => update({ shiftX })} />
      <RangeControl name="Vertical shift" value={animation.shiftY} min={-0.5} max={0.5} step={0.01}
        label={animation.shiftY === 0 ? 'Centered' : percent(animation.shiftY)} onChange={shiftY => update({ shiftY })} />
      <RangeControl name="Stop motion" value={animation.stopFps} min={0} max={24}
        label={animation.stopFps === 0 ? 'Off' : animation.stopFps + ' fps'} onChange={stopFps => update({ stopFps })} />
      <RangeControl name="Eased motion" value={animation.ease} min={0} max={1} step={0.01} label={percent(animation.ease)}
        onChange={ease => update({ ease })} />
    </details>
  </div>;
}
