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
    for (width, height) in [(640, 360), (640, 160), (270, 480)] {
        let mut target = renderer.target(width, height)?;
        let mut previous = Vec::new();
        for look in 0..6 {
            let scene = Scene {
                width,
                height,
                look,
                ..Scene::default()
            };
            let first = target.frame(&scene, 0.0)?;
            assert_ne!(first, target.frame(&scene, 0.25)?, "look {look} is static");
            assert_eq!(
                first,
                target.frame(&scene, 1.0)?,
                "look {look} does not loop"
            );
            assert!(
                previous.iter().all(|pixels| pixels != &first),
                "look {look} duplicates another look"
            );
            previous.push(first);
        }
        println!("All six looks distinct and animated at {width}×{height}");
    }
    Ok(())
}
