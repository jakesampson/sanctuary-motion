use bytemuck::{Pod, Zeroable};
use serde::{Deserialize, Serialize};
use std::io::Write;
use wgpu::util::DeviceExt;

pub const LOOK_COUNT: u32 = 99;
pub const FINISH_COUNT: u32 = 48;
mod overlay;
mod text;
mod tune;
pub use overlay::Overlay;
pub use text::TextSettings;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Scene {
    pub version: u32,
    pub look: u32,
    #[serde(default)]
    pub finish: u32,
    #[serde(default)]
    pub color: ColorSettings,
    #[serde(default)]
    pub animation: AnimationSettings,
    #[serde(default)]
    pub text: TextSettings,
    #[serde(default)]
    pub look_tune: TuneSettings,
    #[serde(default)]
    pub finish_tune: TuneSettings,
    pub seed: u32,
    pub motion: u32,
    pub intensity: f32,
    pub colors: [[u8; 3]; 3],
    pub width: u32,
    pub height: u32,
    pub fps: u32,
    pub duration: u32,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub struct AnimationSettings {
    pub cycles: u32,
    pub movement: f32,
    pub scale: f32,
    pub shift_x: f32,
    pub shift_y: f32,
    pub stop_fps: u32,
    pub ease: f32,
}

impl Default for AnimationSettings {
    fn default() -> Self {
        Self {
            cycles: 1,
            movement: 1.0,
            scale: 1.0,
            shift_x: 0.0,
            shift_y: 0.0,
            stop_fps: 0,
            ease: 0.0,
        }
    }
}

impl AnimationSettings {
    fn phase(&self, phase: f32, duration: u32) -> f32 {
        let mut phase = phase.rem_euclid(1.0);
        if self.stop_fps > 0 {
            let steps = (duration * self.stop_fps) as f32;
            phase = (phase * steps + 0.00001).floor().min(steps - 1.0) / steps;
        }
        let waves = std::f32::consts::TAU * duration.div_ceil(4) as f32;
        let eased = phase - self.ease * (waves * phase).sin() / waves;
        (eased * self.cycles as f32).rem_euclid(1.0)
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub struct ColorSettings {
    pub mode: u32,
    pub glow: Option<[u8; 3]>,
    pub tint: [u8; 3],
    pub amount: f32,
    pub gradient: [[u8; 3]; 4],
    pub layout: u32,
    #[serde(default = "default_slide")]
    pub slide: f32,
    #[serde(default = "default_mid_stop")]
    pub mid_stop: f32,
    #[serde(default = "default_glow_stop")]
    pub glow_stop: f32,
    #[serde(default = "default_glow_tone")]
    pub glow_tone: f32,
    #[serde(default)]
    pub darkness: f32,
}

fn default_slide() -> f32 { 0.5 }
fn default_mid_stop() -> f32 { 0.35 }
fn default_glow_stop() -> f32 { 0.7 }
fn default_glow_tone() -> f32 { 1.0 }

#[derive(Clone, Debug, Deserialize, Serialize, Default)]
#[serde(default, rename_all = "camelCase")]
pub struct TuneSettings {
    pub values: Vec<f32>,
    pub motions: Vec<f32>,
    pub auto: bool,
}

impl TuneSettings {
    fn validate(&self) -> Result<(), String> {
        if self.values.len() > 16
            || self.motions.len() > 16
            || self.values.iter().any(|value| !value.is_finite())
            || self.motions.iter().any(|value| !value.is_finite())
        {
            return Err("Invalid look or finish settings.".into());
        }
        Ok(())
    }
}

impl Default for ColorSettings {
    fn default() -> Self {
        Self {
            mode: 0,
            glow: None,
            tint: [255, 174, 110],
            amount: 1.0,
            gradient: [
                [168, 41, 113],
                [112, 62, 172],
                [54, 120, 204],
                [132, 225, 241],
            ],
            layout: 0,
            slide: 0.5,
            mid_stop: 0.35,
            glow_stop: 0.7,
            glow_tone: 1.0,
            darkness: 0.0,
        }
    }
}

impl Default for Scene {
    fn default() -> Self {
        Self {
            version: 1,
            look: 0,
            finish: 0,
            color: ColorSettings::default(),
            animation: AnimationSettings::default(),
            text: TextSettings::default(),
            look_tune: TuneSettings::default(),
            finish_tune: TuneSettings::default(),
            seed: 1,
            motion: 1,
            intensity: 0.75,
            colors: [[8, 12, 27], [39, 96, 132], [116, 225, 186]],
            width: 1920,
            height: 1080,
            fps: 30,
            duration: 15,
        }
    }
}

impl Scene {
    pub fn validate(&self) -> Result<(), String> {
        debug_assert_eq!(tune::LOOK_TUNE.len(), LOOK_COUNT as usize);
        debug_assert_eq!(tune::FINISH_TUNE.len(), FINISH_COUNT as usize);
        self.text.validate()?;
        self.look_tune.validate()?;
        self.finish_tune.validate()?;
        if self.version != 1
            || self.look >= LOOK_COUNT
            || self.finish >= FINISH_COUNT
            || self.color.mode > 2
            || self.color.layout > 4
            || !(0.0..=1.0).contains(&self.color.amount)
            || !(0.0..=1.0).contains(&self.color.slide)
            || !(0.05..=0.9).contains(&self.color.mid_stop)
            || !(0.1..=0.98).contains(&self.color.glow_stop)
            || !(0.0..=1.0).contains(&self.color.glow_tone)
            || !(0.0..=1.0).contains(&self.color.darkness)
            || self.animation.cycles > 4
            || self.animation.stop_fps > 24
            || !(0.0..=2.0).contains(&self.animation.movement)
            || !(0.5..=3.0).contains(&self.animation.scale)
            || !(-0.5..=0.5).contains(&self.animation.shift_x)
            || !(-0.5..=0.5).contains(&self.animation.shift_y)
            || !(0.0..=1.0).contains(&self.animation.ease)
            || self.motion > 2
            || !(0.0..=1.0).contains(&self.intensity)
            || ![24, 25, 30, 50, 60].contains(&self.fps)
            || !(1..=60).contains(&self.duration)
            || !(1..=8192).contains(&self.width)
            || !(1..=8192).contains(&self.height)
            || u64::from(self.width) * u64::from(self.height) > 16_777_216
        {
            return Err("Unsupported scene values or screen size. Maximum is 8192 pixels per side and 16 megapixels.".into());
        }
        Ok(())
    }
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct Params {
    size: [u32; 2],
    look: u32,
    seed: u32,
    phase: f32,
    energy: f32,
    intensity: f32,
    composition: f32,
    colors: [[f32; 4]; 3],
    surface: [u32; 4],
    tint: [f32; 4],
    glow: [f32; 4],
    gradient: [[f32; 4]; 4],
    framing: [f32; 4],
    text_style: [u32; 4],
    text_flags: [u32; 4],
    text_layout: [f32; 4],
    text_shape: [f32; 4],
    text_color: [f32; 4],
    text_accent: [f32; 4],
    look_tune: [[f32; 4]; 4],
    finish_tune: [[f32; 4]; 2],
    color_tone: [f32; 4],
}

#[derive(Clone)]
pub struct Renderer {
    device: wgpu::Device,
    queue: wgpu::Queue,
    pipeline: wgpu::ComputePipeline,
    pub adapter: String,
}

impl Renderer {
    pub fn new() -> Result<Self, String> {
        let instance = wgpu::Instance::default();
        let adapter =
            pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions::default()))
                .ok_or("A compatible GPU could not be found.")?;
        let info = adapter.get_info();
        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("Sanctuary Motion"),
                required_limits: wgpu::Limits::default(),
                ..Default::default()
            },
            None,
        ))
        .map_err(|e| e.to_string())?;
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Worship looks"),
            source: wgpu::ShaderSource::Wgsl(
                concat!(
                    include_str!("looks.wgsl"),
                    "\n",
                    include_str!("library.wgsl"),
                    "\n",
                    include_str!("finishes.wgsl"),
                    "\n",
                    include_str!("text.wgsl")
                )
                .into(),
            ),
        });
        let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: None,
            layout: None,
            module: &shader,
            entry_point: Some("render"),
            compilation_options: Default::default(),
            cache: None,
        });
        Ok(Self {
            device,
            queue,
            pipeline,
            adapter: format!("{} ({:?})", info.name, info.backend),
        })
    }

    pub fn target(&self, width: u32, height: u32) -> Result<Target, String> {
        if width == 0 || height == 0 || width > 8192 || height > 8192 {
            return Err("Invalid render dimensions.".into());
        }
        let size = u64::from(width) * u64::from(height) * 4;
        if size > u64::from(self.device.limits().max_storage_buffer_binding_size)
            || size > 67_108_864
        {
            return Err("This GPU cannot render the requested dimensions.".into());
        }
        let buffer = |usage| {
            self.device.create_buffer(&wgpu::BufferDescriptor {
                label: None,
                size,
                usage,
                mapped_at_creation: false,
            })
        };
        let output = buffer(wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC);
        let readback = buffer(wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ);
        let params = self
            .device
            .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: None,
                contents: bytemuck::bytes_of(&Params::zeroed()),
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            });
        let atlas = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Text alpha atlas"),
            size: text::BUFFER_BYTES,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let bind = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &self.pipeline.get_bind_group_layout(0),
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: params.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: output.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: atlas.as_entire_binding(),
                },
            ],
        });
        Ok(Target {
            renderer: self.clone(),
            width,
            height,
            size,
            params,
            output,
            readback,
            bind,
            atlas,
            text_key: None,
            text_lines: 0,
            overlay: None,
        })
    }
}

pub struct Target {
    renderer: Renderer,
    width: u32,
    height: u32,
    size: u64,
    params: wgpu::Buffer,
    output: wgpu::Buffer,
    readback: wgpu::Buffer,
    bind: wgpu::BindGroup,
    atlas: wgpu::Buffer,
    text_key: Option<(String, u32)>,
    text_lines: u32,
    overlay: Option<overlay::PreparedOverlay>,
}

impl Target {
    pub fn dimensions(&self) -> (u32, u32) {
        (self.width, self.height)
    }

    pub fn frame(&mut self, scene: &Scene, phase: f32) -> Result<Vec<u8>, String> {
        self.frame_with_text_phase(scene, phase, phase)
    }

    pub fn set_overlay(&mut self, source: Option<(std::sync::Arc<Overlay>, bool)>) {
        self.overlay = match source {
            Some((source, fit)) => {
                if self.overlay.as_ref().is_some_and(|current| {
                    current.fit == fit && std::sync::Arc::ptr_eq(&current.source, &source)
                }) {
                    return;
                }
                Some(overlay::PreparedOverlay::new(
                    source,
                    fit,
                    self.width,
                    self.height,
                ))
            }
            None => None,
        };
    }

    pub fn frame_with_text_phase(
        &mut self,
        scene: &Scene,
        phase: f32,
        text_phase: f32,
    ) -> Result<Vec<u8>, String> {
        scene.validate()?;
        if !phase.is_finite() || !text_phase.is_finite() {
            return Err("Invalid loop phase.".into());
        }
        let text = &scene.text;
        let key = text.key();
        if key != self.text_key {
            self.text_lines = 0;
            if let Some((content, font)) = &key {
                let (pixels, lines) = text::prepare(content, *font)?;
                self.renderer
                    .queue
                    .write_buffer(&self.atlas, 0, bytemuck::cast_slice(&pixels));
                self.text_lines = lines;
            }
            self.text_key = key;
        }
        let motion_phase = scene.animation.phase(phase, scene.duration);
        let params = Params {
            size: [self.width, self.height],
            look: scene.look,
            surface: [scene.finish, scene.color.mode, scene.color.layout, 0],
            tint: rgb(scene.color.tint, scene.color.amount),
            glow: scene.color.glow.map_or([0.0; 4], |color| rgb(color, 1.0)),
            gradient: scene.color.gradient.map(|color| rgb(color, 1.0)),
            framing: [
                scene.animation.scale,
                scene.animation.shift_x,
                scene.animation.shift_y,
                scene.color.glow_tone,
            ],
            text_style: [self.text_lines, text.mode, text.treatment, text.blend],
            text_flags: [text.background, u32::from(text.crt), 0, 0],
            text_layout: [
                text.size,
                text.shift_x,
                text.shift_y,
                text_phase.rem_euclid(1.0) * text.cycles as f32,
            ],
            text_shape: [text.density, text.inner_size, text.spacing, text.glow],
            text_color: rgb(text.foreground, text.opacity),
            text_accent: rgb(text.accent, text.dim),
            look_tune: pack_tune(tune::bake(
                tune::LOOK_TUNE,
                scene.look,
                &scene.look_tune.values,
                &scene.look_tune.motions,
                scene.look_tune.auto,
                motion_phase,
            )),
            finish_tune: pack_finish(tune::bake(
                tune::FINISH_TUNE,
                scene.finish,
                &scene.finish_tune.values,
                &scene.finish_tune.motions,
                scene.finish_tune.auto,
                motion_phase,
            )),
            color_tone: [
                scene.color.slide,
                scene.color.mid_stop,
                scene.color.glow_stop,
                scene.color.darkness,
            ],
            seed: scene.seed,
            phase: motion_phase,
            energy: [0.45, 0.75, 1.0][scene.motion as usize] * scene.animation.movement,
            intensity: scene.intensity,
            composition: scene.width as f32 / scene.height as f32,
            colors: scene
                .colors
                .map(|[r, g, b]| [r as f32 / 255., g as f32 / 255., b as f32 / 255., 1.]),
        };
        let gpu = &self.renderer;
        gpu.queue
            .write_buffer(&self.params, 0, bytemuck::bytes_of(&params));
        let mut commands = gpu.device.create_command_encoder(&Default::default());
        {
            let mut pass = commands.begin_compute_pass(&Default::default());
            pass.set_pipeline(&gpu.pipeline);
            pass.set_bind_group(0, &self.bind, &[]);
            pass.dispatch_workgroups(self.width.div_ceil(8), self.height.div_ceil(8), 1);
        }
        commands.copy_buffer_to_buffer(&self.output, 0, &self.readback, 0, self.size);
        gpu.queue.submit(Some(commands.finish()));
        let slice = self.readback.slice(..);
        let (send, recv) = std::sync::mpsc::channel();
        slice.map_async(wgpu::MapMode::Read, move |result| {
            let _ = send.send(result);
        });
        gpu.device.poll(wgpu::Maintain::Wait);
        recv.recv()
            .map_err(|e| e.to_string())?
            .map_err(|e| e.to_string())?;
        let mut pixels = slice.get_mapped_range().to_vec();
        self.readback.unmap();
        if let Some(overlay) = &self.overlay {
            overlay.blend(&mut pixels, self.width);
        }
        Ok(pixels)
    }
}

fn rgb([r, g, b]: [u8; 3], alpha: f32) -> [f32; 4] {
    [r as f32 / 255.0, g as f32 / 255.0, b as f32 / 255.0, alpha]
}

fn pack_tune(values: [f32; 16]) -> [[f32; 4]; 4] {
    [
        [values[0], values[1], values[2], values[3]],
        [values[4], values[5], values[6], values[7]],
        [values[8], values[9], values[10], values[11]],
        [values[12], values[13], values[14], values[15]],
    ]
}

fn pack_finish(values: [f32; 16]) -> [[f32; 4]; 2] {
    [
        [values[0], values[1], values[2], values[3]],
        [values[4], values[5], values[6], values[7]],
    ]
}

pub fn write_png(out: impl Write, width: u32, height: u32, pixels: &[u8]) -> Result<(), String> {
    let mut encoder = png::Encoder::new(out, width, height);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .write_header()
        .and_then(|mut writer| {
            writer.write_image_data(pixels)?;
            writer.finish()
        })
        .map_err(|e| e.to_string())
}
