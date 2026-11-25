use sanctuary_render::{write_png, Renderer, Scene};
use serde::Deserialize;
use std::{
    io::{Read, Write},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex, MutexGuard,
    },
};
use tauri::{AppHandle, Emitter};
use tempfile::NamedTempFile;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportRequest {
    scene: Scene,
    path: PathBuf,
    format: Format,
}

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
enum Format {
    Png,
    Mp4,
}

#[derive(Default)]
pub struct ExportState {
    active: Mutex<bool>,
    cancelled: AtomicBool,
    encoder: Mutex<Option<Child>>,
}

pub struct Job<'a>(&'a ExportState);

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

impl ExportState {
    pub fn start(&self) -> Result<Job<'_>, String> {
        let mut active = lock(&self.active);
        if *active {
            return Err("An export is already running.".into());
        }
        self.cancelled.store(false, Ordering::Release);
        *active = true;
        Ok(Job(self))
    }

    pub fn cancel(&self) -> Result<(), String> {
        let active = lock(&self.active);
        if *active {
            self.cancelled.store(true, Ordering::Release);
            if let Some(child) = lock(&self.encoder).as_mut() {
                let _ = child.kill();
            }
        }
        Ok(())
    }
}

impl Job<'_> {
    fn check(&self) -> Result<(), String> {
        if self.0.cancelled.load(Ordering::Acquire) {
            return Err("Export cancelled.".into());
        }
        Ok(())
    }
}

impl Drop for Job<'_> {
    fn drop(&mut self) {
        let mut active = lock(&self.0.active);
        if let Some(mut child) = lock(&self.0.encoder).take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        *active = false;
    }
}

pub fn temporary_beside(path: &Path) -> Result<NamedTempFile, String> {
    let parent = path
        .parent()
        .filter(|p| p.is_absolute())
        .ok_or("Choose an absolute file path.")?;
    tempfile::Builder::new()
        .prefix(".sanctuary-")
        .tempfile_in(parent)
        .map_err(|error| format!("Could not create a temporary output file. {error}"))
}

pub fn run(
    app: &AppHandle,
    renderer: &Renderer,
    job: &Job,
    request: ExportRequest,
) -> Result<(), String> {
    let ExportRequest {
        scene,
        path,
        format,
    } = request;
    scene.validate()?;
    let expected = match format {
        Format::Png => "png",
        Format::Mp4 => "mp4",
    };
    if !path
        .extension()
        .and_then(|part| part.to_str())
        .is_some_and(|part| part.eq_ignore_ascii_case(expected))
    {
        return Err(format!("Choose a file with the .{expected} extension."));
    }
    if matches!(format, Format::Mp4) && (scene.width % 2 != 0 || scene.height % 2 != 0) {
        return Err(
            "MP4 requires even width and height. Choose PNG for an odd-sized screen.".into(),
        );
    }
    if path.exists() {
        return Err(
            "A file already exists at this destination. Choose a different filename.".into(),
        );
    }
    let parent = path
        .parent()
        .filter(|parent| parent.is_absolute())
        .ok_or("Choose an absolute output path.")?;
    let staging = tempfile::Builder::new()
        .prefix(".sanctuary-")
        .tempdir_in(parent)
        .map_err(|error| format!("Could not prepare this output folder. {error}"))?;
    let temporary = staging.path().join(format!("output.{expected}"));
    let mut target = renderer.target(scene.width, scene.height)?;
    job.check()?;
    match format {
        Format::Png => {
            let pixels = target.frame(&scene, 0.0)?;
            let out = std::fs::File::create(&temporary).map_err(|error| error.to_string())?;
            write_png(out, scene.width, scene.height, &pixels)?;
        }
        Format::Mp4 => encode(app, job, &scene, &mut target, &temporary)?,
    }
    std::fs::File::options()
        .read(true)
        .write(true)
        .open(&temporary)
        .and_then(|file| file.sync_all())
        .map_err(|error| error.to_string())?;
    // Serialize cancellation with the final rename so that no cancelled job publishes output.
    let _active = lock(&job.0.active);
    job.check()?;
    let temporary =
        tempfile::TempPath::try_from_path(temporary).map_err(|error| error.to_string())?;
    temporary
        .persist_noclobber(path)
        .map_err(|error| format!("Could not save the export. {error}"))?;
    Ok(())
}

fn encode(
    app: &AppHandle,
    job: &Job,
    scene: &Scene,
    target: &mut sanctuary_render::Target,
    file: &Path,
) -> Result<(), String> {
    let mut command = video_command(scene, file)?;
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x0800_0000);
    }
    let mut child = command
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| {
            format!(
                "Could not start the bundled video encoder. Reinstall Sanctuary Motion. {error}"
            )
        })?;
    let mut input = child.stdin.take().expect("piped encoder input");
    let mut stderr = child.stderr.take().expect("piped encoder errors");
    {
        let mut encoder = lock(&job.0.encoder);
        if let Err(error) = job.check() {
            let _ = child.kill();
            let _ = child.wait();
            return Err(error);
        }
        *encoder = Some(child);
    }
    let stderr_reader = std::thread::spawn(move || {
        let mut message = Vec::new();
        let _ = (&mut stderr).take(8192).read_to_end(&mut message);
        let _ = std::io::copy(&mut stderr, &mut std::io::sink());
        String::from_utf8_lossy(&message).trim().to_owned()
    });
    let count = scene.duration * scene.fps;
    let frames = (|| -> Result<(), String> {
        for frame in 0..count {
            job.check()?;
            let rgba = target.frame(scene, frame as f32 / count as f32)?;
            input.write_all(&rgba).map_err(|error| error.to_string())?;
            let _ = app.emit("export-progress", (frame + 1) as f64 / count as f64 * 0.98);
        }
        Ok(())
    })();
    drop(input);
    let status = loop {
        let status = lock(&job.0.encoder)
            .as_mut()
            .expect("registered encoder")
            .try_wait()
            .map_err(|error| error.to_string())?;
        if let Some(status) = status {
            break status;
        }
        std::thread::sleep(std::time::Duration::from_millis(20));
    };
    let detail = stderr_reader.join().unwrap_or_default();
    job.check()?;
    if !status.success() {
        return Err(format!("Could not encode this video. {detail}"));
    }
    frames
}

fn video_command(scene: &Scene, file: &Path) -> Result<Command, String> {
    let executable = std::env::current_exe().map_err(|error| error.to_string())?;
    let name = if cfg!(windows) {
        "sanctuary-encoder.exe"
    } else {
        "sanctuary-encoder"
    };
    let sidecar = executable.with_file_name(name);
    if !sidecar.is_file() {
        return Err("The bundled video encoder is missing. Reinstall Sanctuary Motion.".into());
    }
    let mut command = Command::new(sidecar);
    command
        .args([
            scene.width.to_string(),
            scene.height.to_string(),
            scene.fps.to_string(),
            (scene.duration * scene.fps).to_string(),
        ])
        .arg(file);
    Ok(command)
}
