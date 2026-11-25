use std::path::PathBuf;
use tauri::{webview::PageLoadEvent, Builder, Listener, LogicalSize, Manager, Wry};

pub fn configure(builder: Builder<Wry>) -> Builder<Wry> {
    builder
        .setup(|app| {
            if let Some(path) = std::env::var_os("SANCTUARY_SMOKE_DIR").map(PathBuf::from) {
                let resize = app.handle().clone();
                app.once("smoke-compact", move |_| {
                    if let Some(window) = resize.get_webview_window("main") {
                        let _ = window.set_size(LogicalSize::new(580.0, 700.0));
                    }
                });
                let handle = app.handle().clone();
                app.once("smoke-result", move |event| {
                    let result = event.payload();
                    println!("{result}");
                    let written = std::fs::write(path.join("smoke-result.json"), result).is_ok();
                    let success = written
                        && serde_json::from_str::<serde_json::Value>(result)
                            .is_ok_and(|result| result["ok"] == true);
                    handle.exit(i32::from(!success));
                });
            }
            Ok(())
        })
        .on_page_load(|view, payload| {
            if payload.event() != PageLoadEvent::Finished || view.label() != "main" {
                return;
            }
            if let Ok(path) = std::env::var("SANCTUARY_SMOKE_DIR") {
                let options = serde_json::json!({
                    "dir": path,
                    "fullDisk": std::env::var("SANCTUARY_SMOKE_FULL_DISK").ok(),
                    "missingEncoder": std::env::var_os("SANCTUARY_SMOKE_MISSING_ENCODER").is_some(),
                });
                let script = format!("({})({options});", include_str!("smoke.js"));
                if let Err(error) = view.eval(&script) {
                    eprintln!("Could not start smoke test: {error}");
                    view.app_handle().exit(1);
                }
            }
        })
}
