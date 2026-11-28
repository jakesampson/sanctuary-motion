use image::{Rgb, RgbImage};
use sanctuary_render::{write_png, AnimationSettings, Renderer, Scene, TextSettings, TuneSettings};
use std::{fs, io::BufWriter};

const W: u32 = 480;
const H: u32 = 270;

fn paste(grid: &mut RgbImage, frame: &[u8], x: u32, y: u32) {
    for row in 0..H {
        for col in 0..W {
            let src = ((row * W + col) * 4) as usize;
            grid.put_pixel(x + col, y + row, Rgb([frame[src], frame[src + 1], frame[src + 2]]));
        }
    }
}

fn write_rgb(path: &str, image: &RgbImage) -> Result<(), String> {
    let rgba: Vec<u8> = image.as_raw().chunks_exact(3)
        .flat_map(|pixel| [pixel[0], pixel[1], pixel[2], 255])
        .collect();
    let file = fs::File::create(path).map_err(|error| error.to_string())?;
    write_png(BufWriter::new(file), image.width(), image.height(), &rgba)
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    fs::create_dir_all("artifacts/review").map_err(|error| error.to_string())?;
    let mut target = renderer.target(W, H)?;
    for (label, size) in [("sm", 0.58f32), ("lg", 1.0f32)] {
        let mut sheet = RgbImage::new(W * 5, H * 4);
        for slot in 0..20usize {
            let scene = Scene {
                width: W,
                height: H,
                look: 99 + slot as u32,
                text: TextSettings {
                    enabled: true,
                    content: "Holy\nPrince of Peace".into(),
                    treatment: 20,
                    size,
                    ..Default::default()
                },
                look_tune: TuneSettings { auto: true, ..Default::default() },
                finish_tune: TuneSettings { auto: true, ..Default::default() },
                animation: AnimationSettings { enabled: true, ..Default::default() },
                ..Scene::default()
            };
            let frame = target.frame(&scene, 0.23)?;
            paste(&mut sheet, &frame, (slot % 5) as u32 * W, (slot / 5) as u32 * H);
        }
        write_rgb(&format!("artifacts/review/new-looks-{label}.png"), &sheet)?;
    }
    println!("Wrote new-looks-sm.png and new-looks-lg.png");
    Ok(())
}
