use sanctuary_render::{write_png, AnimationSettings, Renderer, Scene, TextSettings, TuneSettings};
use std::{fs, io::BufWriter};

const WIDTH: u32 = 480;
const HEIGHT: u32 = 270;

fn auto_tune() -> TuneSettings {
    TuneSettings { auto: true, ..Default::default() }
}

fn write_frame(path: &str, frame: &[u8]) -> Result<(), String> {
    let rgba: Vec<u8> = frame.chunks_exact(4)
        .flat_map(|pixel| [pixel[0], pixel[1], pixel[2], 255])
        .collect();
    let file = fs::File::create(path).map_err(|error| error.to_string())?;
    write_png(BufWriter::new(file), WIDTH, HEIGHT, &rgba)
}

fn main() -> Result<(), String> {
    fs::create_dir_all("artifacts/review/finish-probes").map_err(|error| error.to_string())?;
    let renderer = Renderer::new()?;
    let mut target = renderer.target(WIDTH, HEIGHT)?;

    for finish in [21u32, 31u32] {
        let disabled = Scene {
            width: WIDTH,
            height: HEIGHT,
            look: 20,
            finish,
            look_tune: auto_tune(),
            finish_tune: auto_tune(),
            animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
            ..Scene::default()
        };
        write_frame(
            &format!("artifacts/review/finish-probes/finish-{finish}-notext.png"),
            &target.frame(&disabled, 0.23)?,
        )?;

        for (label, treatment, size) in [("arch20-sm", 20u32, 0.58f32), ("arch5-sm", 5u32, 0.58)] {
            let scene = Scene {
                width: WIDTH,
                height: HEIGHT,
                look: 20,
                finish,
                text: TextSettings {
                    enabled: true,
                    content: "Holy\nPrince of Peace".into(),
                    treatment,
                    size,
                    ..Default::default()
                },
                look_tune: auto_tune(),
                finish_tune: auto_tune(),
                animation: AnimationSettings { enabled: true, ..AnimationSettings::default() },
                ..Scene::default()
            };
            write_frame(
                &format!("artifacts/review/finish-probes/finish-{finish}-{label}.png"),
                &target.frame(&scene, 0.23)?,
            )?;
        }
    }

    println!("Wrote finish 21 and 31 probes");
    Ok(())
}
