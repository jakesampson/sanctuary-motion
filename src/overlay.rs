use image::{imageops, ImageFormat, ImageReader, Limits, RgbaImage};
use std::{
    fs::File,
    io::{Cursor, Read},
    path::Path,
    sync::Arc,
};

const MAX_BYTES: u64 = 16 * 1024 * 1024;
const MAX_PIXELS: u64 = 16_777_216;

pub struct Overlay(RgbaImage);

impl Overlay {
    pub fn load(path: &Path) -> Result<Self, String> {
        let file = File::open(path).map_err(|error| error.to_string())?;
        let mut bytes = Vec::new();
        file.take(MAX_BYTES + 1)
            .read_to_end(&mut bytes)
            .map_err(|error| error.to_string())?;
        if bytes.len() as u64 > MAX_BYTES {
            return Err("Choose an overlay under 16 MiB.".into());
        }
        let pixels = match image::guess_format(&bytes) {
            Ok(format @ (ImageFormat::Png | ImageFormat::Jpeg)) => {
                let mut reader = ImageReader::with_format(Cursor::new(bytes), format);
                let mut limits = Limits::default();
                limits.max_image_width = Some(8192);
                limits.max_image_height = Some(8192);
                limits.max_alloc = Some(MAX_PIXELS * 4);
                reader.limits(limits);
                reader
                    .decode()
                    .map_err(|error| format!("Could not decode the overlay. {error}"))?
                    .to_rgba8()
            }
            _ if path
                .extension()
                .and_then(|part| part.to_str())
                .is_some_and(|part| part.eq_ignore_ascii_case("svg")) =>
            {
                read_svg(&bytes)?
            }
            _ => return Err("Choose a PNG, JPEG or SVG overlay.".into()),
        };
        if u64::from(pixels.width()) * u64::from(pixels.height()) > MAX_PIXELS {
            return Err("Overlay exceeds 16 megapixels.".into());
        }
        Ok(Self(pixels))
    }
}

fn read_svg(bytes: &[u8]) -> Result<RgbaImage, String> {
    use resvg::{tiny_skia, usvg};
    let xml = std::str::from_utf8(bytes).map_err(|_| "SVG must be UTF-8.")?;
    let options = usvg::Options {
        // SVG overlays are rendered as local vector artwork with resource resolution disabled.
        image_href_resolver: usvg::ImageHrefResolver {
            resolve_data: Box::new(|_, _, _| None),
            resolve_string: Box::new(|_, _| None),
        },
        ..Default::default()
    };
    let tree = usvg::Tree::from_str(xml, &options)
        .map_err(|error| format!("Could not read the SVG. {error}"))?;
    let size = tree.size();
    let scale = (2048.0 / size.width().max(size.height())).min(1.0);
    let width = (size.width() * scale).ceil().max(1.0) as u32;
    let height = (size.height() * scale).ceil().max(1.0) as u32;
    let mut pixmap = tiny_skia::Pixmap::new(width, height).ok_or("Invalid SVG size.")?;
    resvg::render(
        &tree,
        tiny_skia::Transform::from_scale(scale, scale),
        &mut pixmap.as_mut(),
    );
    let mut bytes = pixmap.take();
    for pixel in bytes.chunks_exact_mut(4) {
        let alpha = u32::from(pixel[3]);
        if alpha > 0 && alpha < 255 {
            for channel in &mut pixel[..3] {
                *channel = ((u32::from(*channel) * 255 + alpha / 2) / alpha).min(255) as u8;
            }
        }
    }
    RgbaImage::from_raw(width, height, bytes).ok_or_else(|| "Invalid SVG pixel data.".into())
}

pub(crate) struct PreparedOverlay {
    pub source: Arc<Overlay>,
    pub fit: bool,
    pixels: RgbaImage,
    x: usize,
    y: usize,
}

impl PreparedOverlay {
    pub fn new(source: Arc<Overlay>, fit: bool, width: u32, height: u32) -> Self {
        let (w, h) = source.0.dimensions();
        let sx = f64::from(width) / f64::from(w);
        let sy = f64::from(height) / f64::from(h);
        let (cx, cy, cw, ch, ow, oh) = if fit {
            let ratio = sx.min(sy);
            (
                0,
                0,
                w,
                h,
                (f64::from(w) * ratio).round().max(1.0) as u32,
                (f64::from(h) * ratio).round().max(1.0) as u32,
            )
        } else {
            let ratio = sx.max(sy);
            let cw = (f64::from(width) / ratio)
                .round()
                .max(1.0)
                .min(f64::from(w)) as u32;
            let ch = (f64::from(height) / ratio)
                .round()
                .max(1.0)
                .min(f64::from(h)) as u32;
            ((w - cw) / 2, (h - ch) / 2, cw, ch, width, height)
        };
        let crop = imageops::crop_imm(&source.0, cx, cy, cw, ch);
        let pixels = imageops::resize(&*crop, ow, oh, imageops::FilterType::Triangle);
        Self {
            source,
            fit,
            pixels,
            x: ((width - ow) / 2) as usize,
            y: ((height - oh) / 2) as usize,
        }
    }

    pub fn blend(&self, frame: &mut [u8], width: u32) {
        let stride = width as usize * 4;
        let overlay_stride = self.pixels.width() as usize * 4;
        for (row, source) in self
            .pixels
            .as_raw()
            .chunks_exact(overlay_stride)
            .enumerate()
        {
            let start = (row + self.y) * stride + self.x * 4;
            let target = &mut frame[start..start + overlay_stride];
            for (src, dst) in source.chunks_exact(4).zip(target.chunks_exact_mut(4)) {
                let a = u32::from(src[3]);
                if a == 0 {
                    continue;
                }
                if a == 255 {
                    dst[..3].copy_from_slice(&src[..3]);
                    continue;
                }
                for channel in 0..3 {
                    dst[channel] =
                        ((u32::from(src[channel]) * a + u32::from(dst[channel]) * (255 - a) + 127)
                            / 255) as u8;
                }
            }
        }
    }
}
