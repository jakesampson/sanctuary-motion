use bytemuck::{Pod, Zeroable};
use serde::{Deserialize, Serialize};
use std::io::Write;
use wgpu::util::DeviceExt;

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Scene {
    pub version: u32,
    pub look: u32,
    pub seed: u32,
    pub motion: u32,
    pub intensity: f32,
    pub colors: [[u8; 3]; 3],
    pub width: u32,
    pub height: u32,
    pub fps: u32,
    pub duration: u32,
}

impl Default for Scene {
    fn default() -> Self {
        Self {
            version: 1,
            look: 0,
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
        if self.version != 1
            || self.look > 5
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
            source: wgpu::ShaderSource::Wgsl(include_str!("looks.wgsl").into()),
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
}

impl Target {
    pub fn dimensions(&self) -> (u32, u32) {
        (self.width, self.height)
    }

    pub fn frame(&mut self, scene: &Scene, phase: f32) -> Result<Vec<u8>, String> {
        scene.validate()?;
        if !phase.is_finite() {
            return Err("Invalid loop phase.".into());
        }
        let params = Params {
            size: [self.width, self.height],
            look: scene.look,
            seed: scene.seed,
            phase: phase.rem_euclid(1.0),
            energy: [0.45, 0.75, 1.0][scene.motion as usize],
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
        let pixels = slice.get_mapped_range().to_vec();
        self.readback.unmap();
        Ok(pixels)
    }
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
