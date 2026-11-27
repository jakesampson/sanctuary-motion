use sanctuary_render::{Renderer, Scene};

fn base() -> Scene {
    Scene {
        width: 384,
        height: 216,
        look: 20,
        text: sanctuary_render::TextSettings {
            enabled: true,
            content: "Holy\nPrince of Peace".into(),
            treatment: 8,
            ..sanctuary_render::TextSettings::default()
        },
        ..Scene::default()
    }
}

fn differs(renderer: &Renderer, a: &Scene, b: &Scene, phase: f32) -> bool {
    let mut target = renderer.target(a.width, a.height).expect("target");
    target.frame(a, phase).expect("frame a") != target.frame(b, phase).expect("frame b")
}

fn check(renderer: &Renderer, dead: &mut Vec<&'static str>, name: &'static str, a: &Scene, b: &Scene, phase: f32) {
    if !differs(renderer, a, b, phase) {
        dead.push(name);
    }
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut dead = Vec::new();
    let mut checked = 0usize;
    let mut run = |name: &'static str, a: Scene, b: Scene, phase: f32| {
        checked += 1;
        check(&renderer, &mut dead, name, &a, &b, phase);
    };

    let a = base();
    let mut b = a.clone();
    b.color.mode = 1;
    run("Color mode", a.clone(), b, 0.23);

    let mut a = base();
    a.color.mode = 0;
    let mut b = a.clone();
    b.color.glow = Some([255, 0, 128]);
    run("Glow color", a, b, 0.23);

    let mut a = base();
    a.color.mode = 1;
    let mut b = a.clone();
    b.color.tint = [0, 0, 255];
    run("Tint", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.color.amount = 0.0;
    run("Tint amount", a, b, 0.23);

    let mut a = base();
    a.color.mode = 2;
    let mut b = a.clone();
    b.color.layout = 1;
    run("Gradient layout", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.color.gradient[0] = [255, 0, 0];
    run("Gradient stop", a, b, 0.23);

    let a = base();
    let mut b = a.clone();
    b.animation.cycles = 0;
    run("Motion speed", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.movement = 0.0;
    run("Movement", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.scale = 3.0;
    run("Framing scale", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.shift_x = 0.35;
    run("Horizontal shift", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.shift_y = -0.35;
    run("Vertical shift", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.stop_fps = 6;
    run("Stop motion", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.animation.ease = 1.0;
    run("Eased motion", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.duration = 1;
    run("Duration", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.motion = 0;
    run("Motion preset", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.intensity = 0.0;
    run("Intensity", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.seed = 99;
    run("Variation seed", a, b, 0.23);

    let mut a = base();
    a.text.enabled = false;
    let mut b = a.clone();
    b.text.enabled = true;
    run("Show text", a, b, 0.23);

    let a = base();
    let mut b = a.clone();
    b.text.content = "Different\nwords".into();
    run("Words", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.mode = 1;
    run("Text mode", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.treatment = 20;
    run("Text treatment", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.font = 2;
    run("Typeface", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.uppercase = true;
    run("All caps", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.size = 2.5;
    run("Text size", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.cycles = 3;
    run("Text speed", a.clone(), b, 0.23);
    let mut arch = base();
    arch.text.treatment = 5;
    let mut b = arch.clone();
    b.text.density = 1.0;
    run("Density", arch.clone(), b, 0.23);
    let mut b = arch.clone();
    b.text.inner_size = 1.0;
    run("Inner size", arch, b, 0.23);
    let mut b = a.clone();
    b.text.spacing = 1.0;
    run("Spacing", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.glow = 1.0;
    run("Text glow", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.opacity = 0.2;
    run("Opacity", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.shift_x = 0.3;
    run("Horizontal text shift", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.shift_y = -0.3;
    run("Vertical text shift", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.blend = 5;
    run("Blend mode", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.foreground = [255, 0, 0];
    run("Text color", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.accent = [0, 255, 0];
    run("Accent", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.crt = true;
    run("CRT scanlines", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.background = 1;
    run("Behind text", a.clone(), b, 0.23);
    let mut b = a.clone();
    b.text.dim = 1.0;
    run("Background dim", a, b, 0.23);

    if dead.is_empty() {
        println!("All {checked} scene-level editor controls visibly change the render.");
    } else {
        println!("{}/{} scene-level controls are wired; dead:", checked - dead.len(), checked);
        for name in &dead {
            println!("  {name}");
        }
    }
    Ok(())
}
