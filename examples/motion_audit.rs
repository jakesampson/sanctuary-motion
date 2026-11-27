use sanctuary_render::{Renderer, Scene};

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(320, 180)?;
    let mut static_looks = Vec::new();
    for look in 0..sanctuary_render::LOOK_COUNT {
        let scene = Scene { width: 320, height: 180, look, ..Scene::default() };
        let first = target.frame(&scene, 0.0)?;
        if first == target.frame(&scene, 0.25)? {
            static_looks.push(look);
        }
    }
    println!("Static looks: {:?}", static_looks);
    let scene = Scene { width: 320, height: 180, look: 51, ..Scene::default() };
    let a = target.frame(&scene, 0.0)?;
    let b = target.frame(&scene, 0.25)?;
    let max_rgb = a.chunks(4).map(|p| p[0].max(p[1]).max(p[2])).max().unwrap_or(0);
    let differing = a.chunks(4).zip(b.chunks(4)).filter(|(x, y)| x[0] != y[0] || x[1] != y[1] || x[2] != y[2]).count();
    println!("look 51 max_rgb={max_rgb} differing_rgb={differing}");
    Ok(())
}
