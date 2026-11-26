#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod export;

use export::{ExportRequest, ExportState};
use sanctuary_render::{Overlay, Renderer, Scene, Target};
use std::{
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
};
use tauri::{ipc::Response, AppHandle, Manager, State};

#[derive(Default)]
struct Graphics {
    renderer: Mutex<Option<Renderer>>,
    preview: Mutex<Option<Target>>,
}

#[derive(Default)]
struct ScreenOverlay(Mutex<Option<Arc<Overlay>>>);

impl ScreenOverlay {
    fn current(&self, fit: Option<bool>) -> Result<Option<(Arc<Overlay>, bool)>, String> {
        match fit {
            None => Ok(None),
            Some(fit) => Ok(self
                .0
                .lock()
                .map_err(|error| error.to_string())?
                .clone()
                .map(|source| (source, fit))),
        }
    }
}

#[tauri::command]
async fn select_overlay(app: AppHandle, path: PathBuf) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || {
        let image = Overlay::load(&path)?;
        let state = app.state::<ScreenOverlay>();
        *state.0.lock().map_err(|error| error.to_string())? = Some(Arc::new(image));
        Ok(())
    })
    .await
    .map_err(|error| error.to_string())?
}

#[tauri::command]
fn clear_overlay(state: State<'_, ScreenOverlay>) -> Result<(), String> {
    *state.0.lock().map_err(|error| error.to_string())? = None;
    Ok(())
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
    text_phase: Option<f32>,
    overlay_fit: Option<bool>,
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
        let target = slot.as_mut().expect("initialized preview");
        target.set_overlay(app.state::<ScreenOverlay>().current(overlay_fit)?);
        let pixels = target.frame_with_text_phase(&scene, phase, text_phase.unwrap_or(phase))?;
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
        let overlay = app.state::<ScreenOverlay>().current(request.overlay_fit)?;
        if request.overlay_fit.is_some() && overlay.is_none() {
            return Err("Choose an overlay before including it in the export.".into());
        }
        export::run(&app, &graphics.get()?, &job, request, overlay)
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
        .manage(ScreenOverlay::default())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            preview_frame,
            open_project,
            save_project,
            export_scene,
            cancel_export,
            select_overlay,
            clear_overlay,
        ]);
    #[cfg(feature = "smoke")]
    let builder = smoke::configure(builder);
    builder
        .run(tauri::generate_context!())
        .expect("Sanctuary Motion could not start");
}

#[cfg(feature = "smoke")]
mod smoke;
