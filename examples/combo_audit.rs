use sanctuary_render::{Renderer, Scene, TextSettings, TuneSettings, FINISH_COUNT, LOOK_COUNT};

const WIDTH: u32 = 160;
const HEIGHT: u32 = 90;

fn auto_tune() -> TuneSettings {
    TuneSettings { auto: true, ..Default::default() }
}

fn scene(look: u32, finish: u32) -> Scene {
    Scene {
        width: WIDTH,
        height: HEIGHT,
        look,
        finish,
        text: TextSettings {
            enabled: true,
            content: "Holy\nPrince of Peace".into(),
            treatment: 20,
            size: 0.58,
            ..Default::default()
        },
        look_tune: auto_tune(),
        finish_tune: auto_tune(),
        ..Scene::default()
    }
}

fn nonblank(frame: &[u8]) -> bool {
    frame.chunks_exact(4).any(|pixel| {
        pixel[0] > 40 || pixel[1] > 40 || pixel[2] > 60
    })
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(WIDTH, HEIGHT)?;
    let mut checked = 0usize;
    let mut blank = Vec::new();
    let mut not_loop_safe = Vec::new();

    for look in 0..LOOK_COUNT {
        for finish in 0..FINISH_COUNT {
            let scene = scene(look, finish);
            let frame = target.frame(&scene, 0.23)?;
            if !nonblank(&frame) {
                blank.push((look, finish));
            }
            let start = target.frame(&scene, 0.0)?;
            let end = target.frame(&scene, 1.0)?;
            if start != end {
                not_loop_safe.push((look, finish));
            }
            checked += 1;
        }
    }

    println!("Checked {checked} look/finish combinations at {WIDTH}x{HEIGHT}.");
    if blank.is_empty() && not_loop_safe.is_empty() {
        println!("No blank frames; every combination is loop-safe.");
    } else {
        if !blank.is_empty() {
            println!("Blank frames ({}):", blank.len());
            for (look, finish) in blank.iter().take(20) {
                println!("  look {look}, finish {finish}");
            }
        }
        if !not_loop_safe.is_empty() {
            println!("Not loop-safe ({}):", not_loop_safe.len());
            for (look, finish) in not_loop_safe.iter().take(20) {
                println!("  look {look}, finish {finish}");
            }
        }
        return Err("combination audit failed".into());
    }
    Ok(())
}
