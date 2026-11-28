use image::{Rgb, RgbImage};
use sanctuary_render::{write_png, AnimationSettings, Renderer, Scene, TextSettings, TuneSettings, FINISH_COUNT, LOOK_COUNT};
use std::{fs, io::BufWriter};

const SMALL_W: u32 = 192;
const SMALL_H: u32 = 108;
const LARGE_W: u32 = 480;
const LARGE_H: u32 = 270;

fn paste(grid: &mut RgbImage, frame: &[u8], x: u32, y: u32, width: u32, height: u32) {
    for row in 0..height {
        for col in 0..width {
            let src = ((row * width + col) * 4) as usize;
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

fn auto_tune() -> TuneSettings {
    TuneSettings { auto: true, ..Default::default() }
}

fn text(size: f32) -> TextSettings {
    TextSettings {
        enabled: true,
        content: "Holy\nPrince of Peace".into(),
        treatment: 20,
        size,
        ..Default::default()
    }
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    fs::create_dir_all("artifacts/review").map_err(|error| error.to_string())?;

    let mut small = renderer.target(SMALL_W, SMALL_H)?;
    let mut looks = RgbImage::new(SMALL_W * 10, SMALL_H * ((LOOK_COUNT as u32 + 9) / 10));
    for index in 0..LOOK_COUNT {
        let scene = Scene {
            width: SMALL_W,
            height: SMALL_H,
            look: index,
            look_tune: auto_tune(),
            finish_tune: auto_tune(),
            animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
            ..Scene::default()
        };
        let frame = small.frame(&scene, 0.23)?;
        paste(&mut looks, &frame, (index % 10) * SMALL_W, (index / 10) * SMALL_H, SMALL_W, SMALL_H);
    }
    write_rgb("artifacts/review/all-looks.png", &looks)?;

    let mut finishes = RgbImage::new(SMALL_W * 8, SMALL_H * 6);
    for index in 0..FINISH_COUNT {
        let scene = Scene {
            width: SMALL_W,
            height: SMALL_H,
            look: 20,
            finish: index,
            text: text(0.58),
            look_tune: auto_tune(),
            finish_tune: auto_tune(),
            animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
            ..Scene::default()
        };
        let frame = small.frame(&scene, 0.23)?;
        paste(&mut finishes, &frame, (index % 8) * SMALL_W, (index / 8) * SMALL_H, SMALL_W, SMALL_H);
    }
    write_rgb("artifacts/review/all-finishes-with-text.png", &finishes)?;

    let selected = [0usize, 21, 29, 30, 31, 32, 33, 36, 44, 45, 46];
    let mut large = renderer.target(LARGE_W, LARGE_H)?;
    for (label, size) in [("sm", 0.58f32), ("lg", 1.0f32)] {
        let mut sheet = RgbImage::new(LARGE_W * 3, LARGE_H * 4);
        for (slot, finish) in selected.iter().enumerate() {
            let scene = Scene {
                width: LARGE_W,
                height: LARGE_H,
                look: 20,
                finish: *finish as u32,
                text: text(size),
                look_tune: auto_tune(),
                finish_tune: auto_tune(),
                animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
                ..Scene::default()
            };
            let frame = large.frame(&scene, 0.23)?;
            paste(
                &mut sheet,
                &frame,
                (slot % 3) as u32 * LARGE_W,
                (slot / 3) as u32 * LARGE_H,
                LARGE_W,
                LARGE_H,
            );
        }
        write_rgb(&format!("artifacts/review/selected-finishes-{label}.png"), &sheet)?;
    }

    println!(
        "Wrote all-looks.png, all-finishes-with-text.png, selected-finishes-sm.png and selected-finishes-lg.png"
    );
    Ok(())
}
