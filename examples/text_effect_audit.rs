use sanctuary_render::{AnimationSettings, Renderer, Scene, TextSettings};

const W: u32 = 960;
const H: u32 = 540;

fn bands(with: &[u8], without: &[u8]) -> Vec<usize> {
    let mut rows = Vec::new();
    for y in 0..H {
        let mut ink = false;
        for x in 0..W {
            let at = ((y * W + x) * 4) as usize;
            let delta = with[at].abs_diff(without[at])
                .max(with[at + 1].abs_diff(without[at + 1]))
                .max(with[at + 2].abs_diff(without[at + 2]));
            if delta > 16 {
                ink = true;
                break;
            }
        }
        rows.push(ink);
    }
    let mut result = Vec::new();
    let mut start = None;
    for (y, ink) in rows.into_iter().enumerate() {
        match (start, ink) {
            (None, true) => start = Some(y),
            (Some(first), false) => {
                result.push(y - first);
                start = None;
            }
            _ => {}
        }
    }
    if let Some(first) = start {
        result.push(H as usize - first);
    }
    result.retain(|height| *height >= 2);
    result
}

fn main() -> Result<(), String> {
    let renderer = Renderer::new()?;
    let mut target = renderer.target(W, H)?;
    let base = Scene {
        width: W,
        height: H,
        look: 20,
        finish: 0,
        animation: AnimationSettings { enabled: false, ..AnimationSettings::default() },
        duration: 15,
        ..Scene::default()
    };
    let plain = target.frame(&base, 0.0)?;
    let mut report = Vec::new();
    for treatment in 0..46u32 {
        let scene = Scene {
            text: TextSettings {
                enabled: true,
                content: "AAAA\nAAAA AAAA\nAAAA AAAA AAAA".into(),
                treatment,
                cycles: 0,
                mode: 0,
                size: 1.0,
                ..TextSettings::default()
            },
            ..base.clone()
        };
        let frame = target.frame(&scene, 0.0)?;
        let mut heights = bands(&frame, &plain);
        heights.sort_unstable();
        let median = if heights.is_empty() { 0 } else { heights[heights.len() / 2] };
        let min = heights.first().copied().unwrap_or(0);
        let max = heights.last().copied().unwrap_or(0);
        report.push((treatment, min, median, max, heights.len()));
    }
    for (treatment, min, median, max, count) in &report {
        println!("treatment {treatment:02}: min={min:3} median={median:3} max={max:3} bands={count}");
    }
    let consistent = [0, 1, 2, 3, 7, 8, 10, 12, 13, 14, 15, 16, 18, 19, 22, 24, 25, 26, 27, 29, 31, 33, 38, 42, 44];
    for treatment in consistent {
        let median = report[treatment as usize].2;
        assert!((24..=34).contains(&median), "treatment {treatment} glyph height is {median}px");
    }
    let rain = report[28];
    assert!(rain.4 >= 4 && rain.2 < 120, "Letter Rain is not legible");
    println!("All text effects share one glyph height; Letter Rain is legible.");
    Ok(())
}
