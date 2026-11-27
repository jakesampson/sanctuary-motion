use sanctuary_render::{write_png, Renderer, Scene, TextSettings};
use std::{fs, fs::File};

fn main() -> Result<(), String> {
    fs::create_dir_all("artifacts/text-artifacts-v6").map_err(|e| e.to_string())?;
    let renderer = Renderer::new()?;
    let mut target = renderer.target(960, 540)?;
    for size in [0.25_f32, 0.5, 0.55, 0.58, 0.6, 0.75, 1.0, 1.5, 2.0, 3.0] {
        let scene = Scene {
            width: 960,
            height: 540,
            text: TextSettings {
                enabled: true,
                content: "Holy\nHoly\nHoly\nPrince of Peace\nKing of Kings".into(),
                treatment: 20,
                size,
                ..TextSettings::default()
            },
            ..Scene::default()
        };
        let pixels = target.frame(&scene, 0.0)?;
        let file = File::create(format!("artifacts/text-artifacts-v6/twin-size-{size:.2}.png"))
            .map_err(|e| e.to_string())?;
        write_png(file, 960, 540, &pixels)?;
    }
    println!("Wrote artifacts/text-artifacts-v6/twin-size-*.png");
    Ok(())
}
