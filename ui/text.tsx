import type { ComponentType } from 'react';
import { ColorField, CollapsibleSection, RangeControl, ResetControl, percent, type RGB } from './controls';

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
const sampleWords = 'Holy\nPrince of Peace\nKing of Kings';

export function TextPanel({ look, finish, Thumbnail, text, onChange, playing, onPlayback, onRestart }: {
  look: number; finish: number;
  Thumbnail: ComponentType<{ look: number; finish: number; text?: TextSettings }>;
  text: TextSettings; onChange: (text: TextSettings) => void; playing: boolean;
  onPlayback: () => void; onRestart: () => void;
}) {
  const update = (value: Partial<TextSettings>) => onChange({ ...text, ...value });
  const ratio = (key: 'density' | 'innerSize' | 'spacing' | 'glow' | 'opacity' | 'dim', name: string) =>
    <RangeControl name={name} value={text[key]} min={0} max={1} step={0.01} defaultValue={initialText[key]}
      label={percent(text[key])} onChange={value => update({ [key]: value })} />;
  return <div className="step-content">
    <div className="card-heading">
      <h2>Text layer</h2>
      <ResetControl name="text layer" onReset={() => onChange({
        ...text,
        enabled: initialText.enabled, content: initialText.content, mode: initialText.mode,
        font: initialText.font, uppercase: initialText.uppercase, size: initialText.size,
      })} />
    </div>
    <div className="editor-actions">
      <button aria-pressed={text.enabled} onClick={() => update(text.enabled
        ? { enabled: false }
        : { enabled: true, content: text.content.trim() ? text.content : sampleWords })}>{text.enabled ? 'Hide text' : 'Show text'}</button>
      <button onClick={onPlayback}>{playing ? 'Pause text' : 'Play text'}</button>
      <button onClick={onRestart}>Restart text</button>
    </div>
    <div className="editor-actions" aria-label="Text mode">
      {['Treatments', 'Ticker', 'Full screen', 'Scroll'].map((name, mode) =>
        <button key={name} aria-pressed={text.mode === mode} onClick={() => update({ mode })}>{name}</button>)}
    </div>
    {text.mode === 0 && <div className="gallery">
      <div className="card-heading">
        <h2>Treatment</h2>
        <span className="size">{treatments[text.treatment]}</span>
        <ResetControl name="treatment" onReset={() => update({ treatment: initialText.treatment })} />
      </div>
      <div className="looks" aria-label="text treatments">
        {treatments.map((name, id) =>
          <button className="look" key={name} aria-pressed={id === text.treatment}
            onClick={() => update({ treatment: id, enabled: true, content: text.content.trim() ? text.content : sampleWords })}>
            <Thumbnail look={look} finish={finish} text={{
              ...text, enabled: true, mode: 0, treatment: id,
              content: text.content.trim() ? text.content : sampleWords,
            }} /><span>{name}</span>
          </button>)}
      </div>
    </div>}
    <label className="field">Words
      <textarea rows={4} maxLength={1024} placeholder={sampleWords} value={text.content}
        onChange={event => update({ content: event.target.value.split(/\r?\n/).slice(0,12).join('\n'), enabled: true })} />
    </label>
    <div className="editor-actions">
      <label className="field">Typeface<select value={text.font} onChange={event => update({ font: Number(event.target.value) })}>
        {['Sans serif', 'Serif', 'Monospace'].map((name,index) => <option key={name} value={index}>{name}</option>)}
      </select></label>
      <label className="toggle"><input type="checkbox" checked={text.uppercase} onChange={event => update({ uppercase: event.target.checked })} /> All caps</label>
    </div>
    <RangeControl name="Font size (all lines)" value={text.size} min={0.25} max={3} step={0.01} defaultValue={initialText.size}
      label={percent(text.size)} onChange={size => update({ size })} />
    <CollapsibleSection title="Text appearance and timing" name="text appearance and timing" onReset={() => update({
      cycles: initialText.cycles, density: initialText.density, innerSize: initialText.innerSize,
      spacing: initialText.spacing, glow: initialText.glow, opacity: initialText.opacity,
      shiftX: initialText.shiftX, shiftY: initialText.shiftY, blend: initialText.blend,
      foreground: initialText.foreground, accent: initialText.accent, crt: initialText.crt,
      background: initialText.background, dim: initialText.dim,
    })}>
      <RangeControl name="Text speed" value={text.cycles} min={0} max={4} defaultValue={initialText.cycles}
        label={text.cycles === 0 ? 'Still' : text.cycles + ' per loop'} onChange={cycles => update({ cycles })} />
      {text.mode === 0 && text.treatment > 0 && text.treatment < 30 && <>
        {ratio('density', 'Density')}{ratio('innerSize', 'Inner size')}
      </>}
      {ratio('spacing','Spacing')}{ratio('glow','Glow')}{ratio('opacity','Opacity')}
      {(['shiftX', 'shiftY'] as const).map((key,index) =>
        <RangeControl key={key} name={(index === 0 ? 'Horizontal' : 'Vertical') + ' text shift'}
          value={text[key]} min={-0.5} max={0.5} step={0.01} defaultValue={initialText[key]}
          label={percent(text[key])} onChange={value => update({ [key]: value })} />)}
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
    </CollapsibleSection>
  </div>;
}
