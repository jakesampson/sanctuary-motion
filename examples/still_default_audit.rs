use sanctuary_render::{Renderer, Scene, TuneSettings, FINISH_COUNT, LOOK_COUNT};

const WIDTH: u32 = 160;
const HEIGHT: u32 = 90;

fn auto_tune() -> TuneSettings {
    TuneSettings { auto: true, ..Default::default() }
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(WIDTH, HEIGHT)?;
    let mut checked = 0usize;
    let mut moving = Vec::new();
    for look in 0..LOOK_COUNT {
        for finish in 0..FINISH_COUNT {
            let scene = Scene {
                width: WIDTH,
                height: HEIGHT,
                look,
                finish,
                motion: 2,
                look_tune: auto_tune(),
                finish_tune: auto_tune(),
                ..Scene::default()
            };
            let first = target.frame(&scene, 0.0)?;
            if first != target.frame(&scene, 0.25)? {
                moving.push((look, finish));
            }
            checked += 1;
        }
    }
    if moving.is_empty() {
        println!("All {checked} look/finish combinations stay still with motion off.");
    } else {
        println!("{} of {checked} combinations moved with motion off:", moving.len());
        for (look, finish) in moving.iter().take(20) {
            println!("  look {look}, finish {finish}");
        }
        return Err("default motion audit failed".into());
    }
    Ok(())
}
