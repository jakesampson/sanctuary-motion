import { ColorField, RangeControl, percent, type RGB } from './controls';

export type TextSettings = {
  enabled: boolean; content: string; mode: number; treatment: number; font: number; uppercase: boolean;
  cycles: number; size: number; density: number; innerSize: number; spacing: number; glow: number;
  opacity: number; shiftX: number; shiftY: number; blend: number; foreground: RGB; accent: RGB;
  crt: boolean; background: number; dim: number;
};

export const initialText: TextSettings = {
  enabled: false, content: '', mode: 0, treatment: 0, font: 0, uppercase: false, cycles: 1,
  size: 1, density: 0.5, innerSize: 0.55, spacing: 0.5, glow: 0.15, opacity: 1, shiftX: 0, shiftY: 0,
  blend: 0, foreground: [244, 241, 233], accent: [255, 181, 126], crt: false, background: 0, dim: 0,
};

// IDs match the native text renderer and remain stable in saved projects.
const treatments = [
  'Plain title', 'Word Rows', 'Stacked Blocks', 'Checker Wall', 'Twin Pillars', 'Arch Wall',
  'Column Field', 'Sweep Wall', 'Flicker Wall', 'Halo Rings', 'Filled Line Chase', 'Crossed Ribbons',
  'Brick Wall', 'Cross Wall', 'Circle Void', 'Diamond Void', 'Window Wall', 'Tilted Wall',
  'Horizon Wall', 'Mirror Wall', 'Twin Arches', 'Three Pillars', 'Frame Wall', 'Letter Columns',
  'Outline Rows', 'Pulse Wall', 'Center Row Glow', 'Split Wall', 'Letter Rain', 'Tile Flip',
  'CRT Glow', 'Candlelight', 'Neon Tube', 'Breathing Glow', 'Chrome Extrude', 'Rim Light',
  'Laser Outline', 'Volumetric Title', 'Spectrum Edge', 'Volumetric Down', 'Volumetric Sweep',
  'Volumetric Spectrum', 'Vellum Sweep', 'Echo Stack', 'Light Through', 'Liquid Word',
];

export function TextPanel({ text, onChange, playing, onPlayback, onRestart }: {
  text: TextSettings; onChange: (text: TextSettings) => void; playing: boolean;
  onPlayback: () => void; onRestart: () => void;
}) {
  const update = (value: Partial<TextSettings>) => onChange({ ...text, ...value });
  const ratio = (key: 'density' | 'innerSize' | 'spacing' | 'glow' | 'opacity' | 'dim', name: string) =>
    <RangeControl name={name} value={text[key]} min={0} max={1} step={0.01}
      label={percent(text[key])} onChange={value => update({ [key]: value })} />;
  return <div className="step-content">
    <div className="card-heading"><h2>Text layer</h2></div>
    <div className="editor-actions">
      <button aria-pressed={text.enabled} onClick={() => update({ enabled: !text.enabled })}>{text.enabled ? 'Hide text' : 'Show text'}</button>
      <button onClick={onPlayback}>{playing ? 'Pause text' : 'Play text'}</button>
      <button onClick={onRestart}>Restart text</button>
    </div>
    <div className="editor-actions" aria-label="Text mode">
      {['Treatments', 'Ticker', 'Full screen', 'Scroll'].map((name, mode) =>
        <button key={name} aria-pressed={text.mode === mode} onClick={() => update({ mode })}>{name}</button>)}
    </div>
    <label className="field">Words
      <textarea rows={4} maxLength={1024} placeholder={'Holy\nPrince of Peace\nKing of Kings'} value={text.content}
        onChange={event => update({ content: event.target.value.split(/\r?\n/).slice(0,12).join('\n'), enabled: true })} />
    </label>
    {text.mode === 0 && <label className="field">Treatment<select value={text.treatment} onChange={event => update({ treatment: Number(event.target.value) })}>
      <optgroup label="Titles"><option value={0}>{treatments[0]}</option>
        {treatments.slice(30).map((name, index) => <option key={name} value={index+30}>{name}</option>)}</optgroup>
      <optgroup label="Text patterns">
        {treatments.slice(1,30).map((name,index) => <option key={name} value={index+1}>{name}</option>)}</optgroup>
    </select></label>}
    <div className="editor-actions">
      <label className="field">Typeface<select value={text.font} onChange={event => update({ font: Number(event.target.value) })}>
        {['Sans serif', 'Serif', 'Monospace'].map((name,index) => <option key={name} value={index}>{name}</option>)}
      </select></label>
      <label className="toggle"><input type="checkbox" checked={text.uppercase} onChange={event => update({ uppercase: event.target.checked })} /> All caps</label>
    </div>
    <RangeControl name="Text size" value={text.size} min={0.25} max={3} step={0.01} label={percent(text.size)}
      onChange={size => update({ size })} />
    <details><summary>Text appearance and timing</summary>
      <RangeControl name="Text speed" value={text.cycles} min={0} max={4}
        label={text.cycles === 0 ? 'Still' : text.cycles + ' per loop'} onChange={cycles => update({ cycles })} />
      {text.mode === 0 && text.treatment > 0 && text.treatment < 30 && <>
        {ratio('density', 'Density')}{ratio('innerSize', 'Inner size')}
      </>}
      {ratio('spacing','Spacing')}{ratio('glow','Glow')}{ratio('opacity','Opacity')}
      {(['shiftX', 'shiftY'] as const).map((key,index) =>
        <RangeControl key={key} name={(index === 0 ? 'Horizontal' : 'Vertical') + ' text shift'}
          value={text[key]} min={-0.5} max={0.5} step={0.01} label={percent(text[key])} onChange={value => update({ [key]: value })} />)}
      <label className="field">Blend mode<select value={text.blend} onChange={event => update({ blend: Number(event.target.value) })}>
        {['Normal','Screen','Overlay','Soft light','Multiply','Add','Color dodge','Difference'].map((name,index) =>
          <option key={name} value={index}>{name}</option>)}
      </select></label>
      <div className="color-fields">
        <ColorField name="Text color" value={text.foreground} onChange={foreground => update({ foreground })} />
        <ColorField name="Accent" value={text.accent} onChange={accent => update({ accent })} />
      </div>
      <label className="toggle"><input type="checkbox" checked={text.crt} onChange={event => update({ crt: event.target.checked })} /> CRT scanlines</label>
      <label className="field">Behind text<select value={text.background} onChange={event => update({ background: Number(event.target.value) })}>
        {['Loop','Black','Green'].map((name,index) => <option key={name} value={index}>{name}</option>)}
      </select></label>
      {text.background === 0 && ratio('dim','Background dim')}
    </details>
  </div>;
}
