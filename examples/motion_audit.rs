use sanctuary_render::{AnimationSettings, Renderer, Scene};

fn animated() -> Scene {
    Scene {
        animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
        ..Scene::default()
    }
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(320, 180)?;
    let mut moving_looks = Vec::new();
    let mut static_defaults = Vec::new();
    for look in 0..sanctuary_render::LOOK_COUNT {
        let still = Scene { width: 320, height: 180, look, ..Scene::default() };
        let first = target.frame(&still, 0.0)?;
        if first != target.frame(&still, 0.25)? {
            static_defaults.push(look);
        }
        let moving = Scene { width: 320, height: 180, look, ..animated() };
        let first = target.frame(&moving, 0.0)?;
        if first == target.frame(&moving, 0.25)? {
            moving_looks.push(look);
        }
    }
    println!("Default-still failures: {:?}", static_defaults);
    println!("Static looks after applying motion: {:?}", moving_looks);
    if !static_defaults.is_empty() || !moving_looks.is_empty() {
        return Err("motion default or applied-motion audit failed".into());
    }
    let scene = Scene { width: 320, height: 180, look: 51, ..animated() };
    let a = target.frame(&scene, 0.0)?;
    let b = target.frame(&scene, 0.25)?;
    let max_rgb = a.chunks(4).map(|p| p[0].max(p[1]).max(p[2])).max().unwrap_or(0);
    let differing = a.chunks(4).zip(b.chunks(4)).filter(|(x, y)| x[0] != y[0] || x[1] != y[1] || x[2] != y[2]).count();
    println!("look 51 max_rgb={max_rgb} differing_rgb={differing}");
    Ok(())
}
