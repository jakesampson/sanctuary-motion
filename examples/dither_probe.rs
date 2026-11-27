use sanctuary_render::{write_png, Renderer, Scene, TuneSettings};
use std::{fs, io::BufWriter};

const WIDTH: u32 = 640;
const HEIGHT: u32 = 360;

fn auto_tune() -> TuneSettings {
    TuneSettings { auto: true, ..Default::default() }
}

fn main() -> Result<(), String> {
    fs::create_dir_all("artifacts/review/dither-probe").map_err(|error| error.to_string())?;
    let renderer = Renderer::new()?;
    let mut target = renderer.target(WIDTH, HEIGHT)?;
    for look in [7u32, 8, 9, 12, 45] {
        let scene = Scene {
            width: WIDTH,
            height: HEIGHT,
            look,
            look_tune: auto_tune(),
            finish_tune: auto_tune(),
            ..Scene::default()
        };
        let frame = target.frame(&scene, 0.23)?;
        let rgba: Vec<u8> = frame.chunks_exact(4)
            .flat_map(|pixel| [pixel[0], pixel[1], pixel[2], 255])
            .collect();
        let path = format!("artifacts/review/dither-probe/look-{look}.png");
        let file = fs::File::create(path).map_err(|error| error.to_string())?;
        write_png(BufWriter::new(file), WIDTH, HEIGHT, &rgba)?;
    }
    println!("Wrote dither probe frames");
    Ok(())
}
