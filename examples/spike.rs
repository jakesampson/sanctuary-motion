use sanctuary_render::{write_png, Renderer, Scene};
use std::{fs, time::Instant};

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    println!("{}", renderer.adapter);
    fs::create_dir_all("artifacts").map_err(|e| e.to_string())?;
    for (width, height) in [(1920, 1080), (3840, 960)] {
        let scene = Scene {
            width,
            height,
            ..Scene::default()
        };
        let mut target = renderer.target(width, height)?;
        let first = target.frame(&scene, 0.0)?;
        assert_eq!(first, target.frame(&scene, 1.0)?);
        assert_ne!(first, target.frame(&scene, 0.25)?);
        let start = Instant::now();
        for frame in 0..30 {
            target.frame(&scene, frame as f32 / 30.0)?;
        }
        println!(
            "{width}×{height}: {:.2} ms/frame (30 frames)",
            start.elapsed().as_secs_f64() * 1000. / 30.
        );
        let file = fs::File::create(format!("artifacts/aurora-{width}x{height}.png"))
            .map_err(|e| e.to_string())?;
        write_png(file, width, height, &first)?;
    }
    Ok(())
}
