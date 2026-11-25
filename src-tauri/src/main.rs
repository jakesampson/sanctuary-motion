#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod export;

use export::{ExportRequest, ExportState};
use sanctuary_render::{Renderer, Scene, Target};
use std::{fs, path::PathBuf, sync::Mutex};
use tauri::{ipc::Response, AppHandle, Manager, State};

#[derive(Default)]
struct Graphics {
    renderer: Mutex<Option<Renderer>>,
    preview: Mutex<Option<Target>>,
}

impl Graphics {
    fn get(&self) -> Result<Renderer, String> {
        let mut slot = self.renderer.lock().map_err(|error| error.to_string())?;
        if slot.is_none() {
            *slot = Some(Renderer::new()?);
        }
        Ok(slot.as_ref().expect("initialized graphics").clone())
    }
}

#[tauri::command]
async fn preview_frame(
    app: AppHandle,
    scene: Scene,
    phase: f32,
    width: u32,
    height: u32,
) -> Result<Response, String> {
    if width > 960 || height > 960 {
        return Err("Preview exceeds the supported size.".into());
    }
    tauri::async_runtime::spawn_blocking(move || {
        let graphics = app.state::<Graphics>();
        let renderer = graphics.get()?;
        if (width, height) == (144, 81) {
            return Ok(Response::new(
                renderer.target(width, height)?.frame(&scene, phase)?,
            ));
        }
        let mut slot = graphics.preview.lock().map_err(|error| error.to_string())?;
        if slot.as_ref().map(Target::dimensions) != Some((width, height)) {
            *slot = Some(renderer.target(width, height)?);
        }
        let pixels = slot
            .as_mut()
            .expect("initialized preview")
            .frame(&scene, phase)?;
        Ok(Response::new(pixels))
    })
    .await
    .map_err(|error| error.to_string())?
}

const MAX_PROJECT_BYTES: u64 = 64 * 1024;

#[tauri::command]
fn open_project(path: PathBuf) -> Result<Scene, String> {
    use std::io::Read;
    let file = fs::File::open(path).map_err(|error| error.to_string())?;
    let mut bytes = Vec::new();
    file.take(MAX_PROJECT_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| error.to_string())?;
    if bytes.len() as u64 > MAX_PROJECT_BYTES {
        return Err("This file is too large to be a Sanctuary Motion project.".into());
    }
    let scene: Scene = serde_json::from_slice(&bytes)
        .map_err(|error| format!("Could not read this Sanctuary Motion project. {error}"))?;
    scene.validate()?;
    Ok(scene)
}

#[tauri::command]
fn save_project(path: PathBuf, scene: Scene) -> Result<(), String> {
    scene.validate()?;
    let mut file = export::temporary_beside(&path)?;
    serde_json::to_writer_pretty(file.as_file_mut(), &scene).map_err(|error| error.to_string())?;
    file.as_file()
        .sync_all()
        .map_err(|error| error.to_string())?;
    file.persist(path).map_err(|error| error.to_string())?;
    Ok(())
}

#[tauri::command]
async fn export_scene(app: AppHandle, request: ExportRequest) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || {
        let state = app.state::<ExportState>();
        let job = state.start()?;
        let graphics = app.state::<Graphics>();
        export::run(&app, &graphics.get()?, &job, request)
    })
    .await
    .map_err(|error| error.to_string())?
}

#[tauri::command]
fn cancel_export(state: State<'_, ExportState>) -> Result<(), String> {
    state.cancel()
}

fn main() {
    let builder = tauri::Builder::default()
        .manage(Graphics::default())
        .manage(ExportState::default())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            preview_frame,
            open_project,
            save_project,
            export_scene,
            cancel_export,
        ]);
    #[cfg(feature = "smoke")]
    let builder = smoke::configure(builder);
    builder
        .run(tauri::generate_context!())
        .expect("Sanctuary Motion could not start");
}

#[cfg(feature = "smoke")]
mod smoke;
