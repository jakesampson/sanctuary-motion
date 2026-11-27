use sanctuary_render::{write_png, Renderer, Scene};
use std::{fs, fs::File};

fn main() -> Result<(), String> {
    fs::create_dir_all("artifacts/twin-arches-final").map_err(|e| e.to_string())?;
    let renderer = Renderer::new()?;
    let mut target = renderer.target(960, 540)?;
    for treatment in [0u32, 5, 9, 20] {
        let scene = Scene {
            width: 960,
            height: 540,
            text: sanctuary_render::TextSettings {
                enabled: true,
                content: "JESUS".into(),
                treatment,
                ..sanctuary_render::TextSettings::default()
            },
            ..Scene::default()
        };
        let pixels = target.frame(&scene, 0.0)?;
        let file = File::create(format!("artifacts/twin-arches-final/treatment-{treatment:02}.png"))
            .map_err(|e| e.to_string())?;
        write_png(file, 960, 540, &pixels)?;
    }
    for word in ["PRINCE", "WORSHIP"] {
        let scene = Scene {
            width: 960,
            height: 540,
            text: sanctuary_render::TextSettings {
                enabled: true,
                content: word.into(),
                treatment: 20,
                ..sanctuary_render::TextSettings::default()
            },
            ..Scene::default()
        };
        let pixels = target.frame(&scene, 0.0)?;
        let file = File::create(format!("artifacts/twin-arches-final/twin-{word}.png"))
            .map_err(|e| e.to_string())?;
        write_png(file, 960, 540, &pixels)?;
    }
    println!("Wrote artifacts/twin-arches-final/treatment-{{00,05,09,20}}.png and twin word probes");
    Ok(())
}
