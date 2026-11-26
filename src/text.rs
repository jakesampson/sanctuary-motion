use cosmic_text::{
    Attrs, Buffer, Color, Family, FontSystem, Metrics, Shaping, SwashCache, Weight, Wrap,
};
use serde::{Deserialize, Serialize};
use std::sync::{Mutex, OnceLock};

const WIDTH: usize = 1024;
const ROW_HEIGHT: usize = 96;
const MAX_LINES: usize = 12;
pub const BUFFER_BYTES: u64 = (MAX_LINES * (4 + WIDTH * ROW_HEIGHT)) as u64;
pub const TREATMENT_COUNT: u32 = 46;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub struct TextSettings {
    pub enabled: bool,
    pub content: String,
    pub mode: u32,
    pub treatment: u32,
    pub font: u32,
    pub uppercase: bool,
    pub cycles: u32,
    pub size: f32,
    pub density: f32,
    pub inner_size: f32,
    pub spacing: f32,
    pub glow: f32,
    pub opacity: f32,
    pub shift_x: f32,
    pub shift_y: f32,
    pub blend: u32,
    pub foreground: [u8; 3],
    pub accent: [u8; 3],
    pub crt: bool,
    pub background: u32,
    pub dim: f32,
}

impl Default for TextSettings {
    fn default() -> Self {
        Self {
            enabled: false,
            content: String::new(),
            mode: 0,
            treatment: 0,
            font: 0,
            uppercase: false,
            cycles: 1,
            size: 1.0,
            density: 0.5,
            inner_size: 0.55,
            spacing: 0.5,
            glow: 0.15,
            opacity: 1.0,
            shift_x: 0.0,
            shift_y: 0.0,
            blend: 0,
            foreground: [244, 241, 233],
            accent: [255, 181, 126],
            crt: false,
            background: 0,
            dim: 0.0,
        }
    }
}

impl TextSettings {
    pub fn validate(&self) -> Result<(), String> {
        if self.content.len() > 4096
            || self.content.lines().count() > MAX_LINES
            || self.font > 2
            || self.mode > 3
            || self.treatment >= TREATMENT_COUNT
            || self.cycles > 4
            || self.blend > 7
            || self.background > 2
            || !(0.25..=3.0).contains(&self.size)
            || !(-0.5..=0.5).contains(&self.shift_x)
            || !(-0.5..=0.5).contains(&self.shift_y)
            || [
                self.density,
                self.inner_size,
                self.spacing,
                self.glow,
                self.opacity,
                self.dim,
            ]
            .iter()
            .any(|value| !(0.0..=1.0).contains(value))
        {
            return Err("Invalid text settings. Use up to 12 lines and 4096 UTF-8 bytes.".into());
        }
        Ok(())
    }

    pub fn key(&self) -> Option<(String, u32)> {
        if !self.enabled || self.content.trim().is_empty() {
            return None;
        }
        let content = if self.uppercase {
            self.content.to_uppercase()
        } else {
            self.content.clone()
        };
        Some((content, self.font))
    }
}

struct FontCache {
    fonts: FontSystem,
    raster: SwashCache,
}

pub fn prepare(content: &str, font: u32) -> Result<(Vec<u32>, u32), String> {
    static FONTS: OnceLock<Mutex<FontCache>> = OnceLock::new();
    let mut lock = FONTS
        .get_or_init(|| {
            Mutex::new(FontCache {
                fonts: FontSystem::new(),
                raster: SwashCache::new(),
            })
        })
        .lock()
        .map_err(|error| error.to_string())?;
    let FontCache { fonts, raster } = &mut *lock;
    let family = match font {
        1 => Family::Serif,
        2 => Family::Monospace,
        _ => Family::SansSerif,
    };
    let attrs = Attrs::new().family(family).weight(Weight::BOLD);
    let mut atlas = vec![0u32; BUFFER_BYTES as usize / 4];
    let mut line_count = 0;
    for (index, line) in content.lines().take(MAX_LINES).enumerate() {
        line_count += 1;
        if line.trim().is_empty() {
            continue;
        }
        let mut buffer = Buffer::new(fonts, Metrics::new(72.0, ROW_HEIGHT as f32));
        buffer.set_wrap(Wrap::None);
        buffer.set_size(None, Some(ROW_HEIGHT as f32));
        buffer.set_text(line, &attrs, Shaping::Advanced, None);
        buffer.shape_until_scroll(fonts, false);
        let width = buffer.layout_runs().next().map_or(0.0, |run| run.line_w);
        if width > WIDTH as f32 - 4.0 {
            buffer.set_metrics(Metrics::new(
                (72.0 * (WIDTH as f32 - 4.0) / width).max(0.5),
                ROW_HEIGHT as f32,
            ));
        }
        let first_word = MAX_LINES + index * WIDTH * ROW_HEIGHT / 4;
        let mut bounds = (WIDTH, ROW_HEIGHT, 0, 0);
        let mut alpha = vec![0u8; WIDTH * ROW_HEIGHT];
        buffer.draw(
            fonts,
            raster,
            Color::rgb(255, 255, 255),
            |x, y, w, h, color| {
                if color.a() == 0 {
                    return;
                }
                for yy in y.max(0)..(y + h as i32).min(ROW_HEIGHT as i32) {
                    for xx in x.max(0)..(x + w as i32).min(WIDTH as i32) {
                        let (xx, yy) = (xx as usize, yy as usize);
                        alpha[yy * WIDTH + xx] = alpha[yy * WIDTH + xx].max(color.a());
                        bounds = (
                            bounds.0.min(xx),
                            bounds.1.min(yy),
                            bounds.2.max(xx + 1),
                            bounds.3.max(yy + 1),
                        );
                    }
                }
            },
        );
        if bounds.0 >= bounds.2 || bounds.1 >= bounds.3 {
            continue;
        }
        let glyph_width = bounds.2 - bounds.0;
        let glyph_height = bounds.3 - bounds.1;
        atlas[index] = glyph_width as u32 | ((glyph_height as u32) << 16);
        for y in 0..glyph_height {
            for x in 0..glyph_width {
                let at = y * WIDTH + x;
                atlas[first_word + at / 4] |=
                    u32::from(alpha[(y + bounds.1) * WIDTH + x + bounds.0]) << (8 * (at % 4));
            }
        }
    }
    Ok((atlas, line_count))
}
