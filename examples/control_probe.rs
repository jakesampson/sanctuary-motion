use sanctuary_render::{Renderer, Scene, FINISH_TUNE, LOOK_TUNE};

fn scene_with_value(kind: &str, index: u32, control: usize, value: f32) -> Scene {
    let table = if kind == "look" { LOOK_TUNE } else { FINISH_TUNE };
    let spec = table[index as usize];
    let values = spec.iter().map(|row| row[2]).collect::<Vec<_>>();
    let motions = vec![0.0; spec.len()];
    let mut scene = Scene {
        width: 384,
        height: 216,
        look: if kind == "look" { index } else { 20 },
        finish: if kind == "finish" { index } else { 0 },
        ..Scene::default()
    };
    let tune = if kind == "look" {
        &mut scene.look_tune
    } else {
        &mut scene.finish_tune
    };
    tune.values = values;
    tune.motions = motions;
    tune.auto = false;
    tune.values[control] = value;
    scene
}

fn difference(a: &[u8], b: &[u8]) -> (usize, u8) {
    let mut changed = 0;
    let mut peak = 0;
    for (left, right) in a.iter().zip(b) {
        let delta = left.abs_diff(*right);
        if delta != 0 {
            changed += 1;
            peak = peak.max(delta);
        }
    }
    (changed, peak)
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(384, 216)?;
    let mut dead = Vec::new();
    let mut checked = 0;

    for (kind, table) in [("look", LOOK_TUNE), ("finish", FINISH_TUNE)] {
        for index in 0..table.len() as u32 {
            for control in 0..table[index as usize].len() {
                let [min, max, default, _] = table[index as usize][control];
                if min == max || min == default && max == default {
                    continue;
                }
                let mut visible = false;
                let mut best = (0usize, 0u8);
                for phase in [0.0, 0.23] {
                    let low = scene_with_value(kind, index, control, min);
                    let high = scene_with_value(kind, index, control, max);
                    let pixels_low = target.frame(&low, phase)?;
                    let pixels_high = target.frame(&high, phase)?;
                    let diff = difference(&pixels_low, &pixels_high);
                    if diff > best {
                        best = diff;
                    }
                    if diff.0 > 0 {
                        visible = true;
                        break;
                    }
                }
                checked += 1;
                if !visible {
                    dead.push((kind, index, control, best));
                }
            }
        }
    }

    if dead.is_empty() {
        println!("All {checked} declared look/finish controls visibly change the render.");
    } else {
        println!("{}/{} controls are visibly wired; {} are dead:", checked - dead.len(), checked, dead.len());
        for (kind, index, control, best) in &dead {
            println!("  {kind} {index} control {control} (changed bytes {}, peak {})", best.0, best.1);
        }
    }
    Ok(())
}
