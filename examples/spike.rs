use sanctuary_render::{write_png, AnimationSettings, Overlay, Renderer, Scene};
use std::{fs, path::Path, sync::Arc, time::Instant};

fn animated() -> Scene {
    Scene {
        animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
        ..Scene::default()
    }
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    println!("{}", renderer.adapter);
    verify_motion(&renderer)?;
    fs::create_dir_all("artifacts").map_err(|e| e.to_string())?;
    for (width, height) in [(1920, 1080), (3840, 960)] {
        let scene = Scene {
            width,
            height,
            ..animated()
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
        for look in 0..sanctuary_render::LOOK_COUNT {
            let scene = Scene {
                width,
                height,
                look,
                ..animated()
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
        println!(
            "All {} looks distinct and animated at {width}×{height}",
            sanctuary_render::LOOK_COUNT
        );
    }
    let scene = Scene {
        look: 20,
        ..animated()
    };
    let mut target = renderer.target(384, 216)?;
    let mut finishes = Vec::new();
    for finish in 0..sanctuary_render::FINISH_COUNT {
        let scene = Scene {
            finish,
            ..scene.clone()
        };
        let first = target.frame(&scene, 0.0)?;
        assert_eq!(
            first,
            target.frame(&scene, 1.0)?,
            "finish {finish} breaks the loop"
        );
        assert!(
            finishes.iter().all(|pixels| pixels != &first),
            "finish {finish} is duplicated"
        );
        finishes.push(first);
    }
    println!(
        "All {} finishes distinct and loop-safe",
        sanctuary_render::FINISH_COUNT
    );
    let mut styled = scene.clone();
    styled.color.mode = 1;
    assert_ne!(target.frame(&scene, 0.0)?, target.frame(&styled, 0.0)?);
    styled.color.amount = 0.0;
    assert_eq!(target.frame(&scene, 0.0)?, target.frame(&styled, 0.0)?);
    styled.color.mode = 2;
    let split = target.frame(&styled, 0.0)?;
    for layout in 1..5 {
        styled.color.layout = layout;
        assert_ne!(split, target.frame(&styled, 0.0)?);
    }
    styled.animation.cycles = 2;
    styled.animation.stop_fps = 6;
    styled.animation.ease = 0.35;
    assert_eq!(target.frame(&styled, 0.0)?, target.frame(&styled, 0.001)?);
    assert_eq!(target.frame(&styled, 0.0)?, target.frame(&styled, 1.0)?);
    println!("Color modes, eased timing and held frames passed");
    let mut text_scene = scene.clone();
    text_scene.text.enabled = true;
    text_scene.text.content = "Holy\nPrince of Peace\nLumière".into();
    let plain = target.frame(&scene, 0.0)?;
    let mut treatments = Vec::new();
    for treatment in 0..46 {
        text_scene.text.treatment = treatment;
        let rendered = target.frame(&text_scene, 0.0)?;
        assert_ne!(plain, rendered, "text treatment {treatment} did not render");
        assert_eq!(rendered, target.frame(&text_scene, 1.0)?);
        assert!(
            !treatments.contains(&rendered),
            "text treatment {treatment} duplicates another treatment"
        );
        treatments.push(rendered);
    }
    for mode in 1..4 {
        text_scene.text.mode = mode;
        assert_ne!(plain, target.frame(&text_scene, 0.0)?);
    }
    println!("All text treatments distinct and all layout modes rendered");
    for extension in ["png", "jpg"] {
        let name = format!("artifacts/overlay-fixture.{extension}");
        image::RgbImage::from_pixel(7, 5, image::Rgb([238, 25, 116]))
            .save(&name)
            .map_err(|error| error.to_string())?;
        let overlay = Arc::new(Overlay::load(Path::new(&name))?);
        target.set_overlay(Some((overlay.clone(), true)));
        let fit = target.frame(&scene, 0.0)?;
        target.set_overlay(Some((overlay, false)));
        let fill = target.frame(&scene, 0.0)?;
        assert_ne!(fit, fill, "{extension} Fit and Fill must differ");
        assert_ne!(plain, fill);
        target.set_overlay(None);
        assert_eq!(plain, target.frame(&scene, 0.0)?);
    }
    println!("PNG and JPEG overlays passed Fit, Fill and clear");
    Ok(())
}

fn verify_motion(renderer: &Renderer) -> Result<(), String> {
    let mut target = renderer.target(384, 216)?;
    let moving = animated();
    let baseline = target.frame(&moving, 0.125)?;
    let mut faster = moving.clone();
    faster.animation.cycles = 2;
    faster.animation.ease = 0.0;
    let mut linear = moving.clone();
    linear.animation.ease = 0.0;
    let equivalent_time = 0.125 * faster.animation.cycles as f32 / linear.animation.cycles as f32;
    assert_eq!(target.frame(&faster, 0.125)?, target.frame(&linear, equivalent_time)?);
    faster.animation.cycles = 0;
    assert_eq!(target.frame(&faster, 0.125)?, target.frame(&faster, 0.625)?);

    for (name, change) in [
        (
            "movement",
            (|scene: &mut Scene| scene.animation.movement = 0.0) as fn(&mut Scene),
        ),
        ("scale", |scene| scene.animation.scale = 1.5),
        ("horizontal shift", |scene| scene.animation.shift_x = 0.2),
        ("vertical shift", |scene| scene.animation.shift_y = 0.2),
        ("motion preset", |scene| scene.motion = 2),
    ] {
        let mut adjusted = moving.clone();
        change(&mut adjusted);
        assert_ne!(
            target.frame(&adjusted, 0.125)?,
            baseline,
            "{name} has no effect"
        );
        assert_eq!(
            target.frame(&adjusted, 0.0)?,
            target.frame(&adjusted, 1.0)?,
            "{name} breaks the loop"
        );
    }

    let mut held = moving.clone();
    held.animation.stop_fps = 6;
    let first = target.frame(&held, 0.0)?;
    assert_eq!(first, target.frame(&held, 0.01)?);
    held.duration = 40;
    assert_ne!(first, target.frame(&held, 0.01)?);
    assert_eq!(first, target.frame(&held, 1.0)?);

    let mut eased = moving.clone();
    eased.animation.ease = 1.0;
    assert_ne!(
        target.frame(&moving, 0.0625)?,
        target.frame(&eased, 0.0625)?
    );
    assert_eq!(target.frame(&eased, 0.0)?, target.frame(&eased, 1.0)?);
    println!("Speed, duration, movement, framing, presets, frame holds and easing passed");
    Ok(())
}
