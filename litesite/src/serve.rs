use anyhow::{Context, Result, anyhow};
use axum::body::Body;
use axum::extract::ws::{Message, Utf8Bytes, WebSocket};
use axum::extract::{Request, State, WebSocketUpgrade};
use axum::http::{HeaderMap, HeaderValue, Method, StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::get;
use axum::{Router, serve};
use env_logger::fmt::Formatter;
use futures::{SinkExt, StreamExt};
use log::{Level, LevelFilter, Record};
use mime_guess::mime;
use notify::{Error, EventKind, RecommendedWatcher, RecursiveMode};
use notify_debouncer_full::{
    DebounceEventResult, DebouncedEvent, Debouncer, RecommendedCache, new_debouncer,
};
use std::borrow::Cow;
use std::env;
use std::fs;
use std::io::ErrorKind as IoErrorKind;
use std::io::IsTerminal;
use std::io::Write;
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Once};
use std::time::Duration;
use tokio::net::TcpListener;
use tokio::runtime::Handle;
use tokio::sync::broadcast;
use tokio::sync::mpsc::{Receiver, channel};

const WEBSOCKET_FUNCTION: &str = include_str!("serve_websocket.js");
const RELOAD_PAYLOAD: &str = include_str!("serve_reload.js");
static LOGGER_INIT: Once = Once::new();

struct AppState {
    root: PathBuf,
    tx: Arc<broadcast::Sender<()>>,
}

#[derive(Clone, Copy)]
enum LogLevel {
    Info,
    Warn,
    Error,
}

pub async fn serve_site(root: &Path) -> Result<()> {
    init_logger();

    let public = root.join("src/public");
    let public_display = format_root_display(root, &public);
    let serve_root = public
        .canonicalize()
        .unwrap_or_else(|_| public.clone());
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{port}");

    if env::var("LITESITE_SERVE_ONCE").is_ok() {
        log::info!("Serving on http://127.0.0.1:{port}");
        log::info!("Root: {public_display}");
        log::info!("Listening on http://{addr}");
        log::info!("Press Ctrl-C to stop.");
        return Ok(());
    }

    let listener = TcpListener::bind(&addr)
        .await
        .map_err(|error| anyhow!("litesite: failed to bind {addr}: {error}"))?;
    let local_addr = listener
        .local_addr()
        .context("litesite: failed to read bound address")?;
    log::info!("Serving on http://127.0.0.1:{}", local_addr.port());
    log::info!("Root: {public_display}");
    log::info!("Listening on http://{}:{}", local_addr.ip(), local_addr.port());
    log::info!("Press Ctrl-C to stop.");

    let (tx, _) = broadcast::channel(16);
    let tx = Arc::new(tx);
    let state = Arc::new(AppState {
        root: serve_root.clone(),
        tx: tx.clone(),
    });

    let (debouncer, rx) = create_recommended_watcher().await?;
    let watcher = tokio::spawn(watch_for_changes(serve_root, debouncer, rx, tx));

    let router = Router::new()
        .route("/live-server-ws", get(ws_handler))
        .route("/", get(static_assets))
        .route("/{*path}", get(static_assets))
        .with_state(state);

    let result = serve(listener, router).await;
    watcher.abort();

    result.map_err(|error| anyhow!("litesite: preview server failed: {error}"))
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let tx = state.tx.clone();
    ws.on_upgrade(move |socket| on_websocket_upgrade(socket, tx))
}

async fn on_websocket_upgrade(socket: WebSocket, tx: Arc<broadcast::Sender<()>>) {
    log::info!("Browser Connected");
    let (mut sender, mut receiver) = socket.split();
    let mut rx = tx.subscribe();

    let mut send_task = tokio::spawn(async move {
        while rx.recv().await.is_ok() {
            if sender.send(Message::Text(Utf8Bytes::default())).await.is_err() {
                break;
            }
        }
    });

    let mut recv_task =
        tokio::spawn(async move { while let Some(Ok(_)) = receiver.next().await {} });

    tokio::select! {
        _ = (&mut send_task) => recv_task.abort(),
        _ = (&mut recv_task) => send_task.abort(),
    };
}

async fn static_assets(
    State(state): State<Arc<AppState>>,
    req: Request<Body>,
) -> (StatusCode, HeaderMap, Body) {
    let method = req.method().clone();
    let is_reload = req.uri().query().is_some_and(|query| query == "reload");
    let uri_path = req.uri().path().to_string();

    let response = serve_request(&state.root, &uri_path, is_reload);
    if !is_reload {
        log_access(&method, &uri_path, response.0, response.3.as_deref());
    }

    (response.0, response.1, response.2)
}

fn serve_request(
    root: &Path,
    uri_path: &str,
    is_reload: bool,
) -> (StatusCode, HeaderMap, Body, Option<String>) {
    if uri_path.starts_with("//") {
        let redirect = format!("/{}", uri_path.trim_start_matches('/'));
        let mut headers = HeaderMap::new();
        headers.append(header::LOCATION, HeaderValue::from_str(&redirect).unwrap());
        return (
            StatusCode::TEMPORARY_REDIRECT,
            headers,
            Body::empty(),
            Some(redirect),
        );
    }

    let Some(relative_path) = sanitize_uri_path(uri_path) else {
        return (
            StatusCode::FORBIDDEN,
            text_headers("text/plain; charset=utf-8"),
            Body::from("forbidden"),
            None,
        );
    };

    let mut path = root.join(&relative_path);
    let mut access_target = path.strip_prefix(root).ok().map(display_relative_path);
    let is_accessing_dir = path.is_dir();
    if is_accessing_dir {
        if !uri_path.ends_with('/') {
            let redirect = format!("{uri_path}/");
            let mut headers = HeaderMap::new();
            headers.append(header::LOCATION, HeaderValue::from_str(&redirect).unwrap());
            return (
                StatusCode::TEMPORARY_REDIRECT,
                headers,
                Body::empty(),
                Some(redirect),
            );
        }
        path.push("index.html");
        access_target = path.strip_prefix(root).ok().map(display_relative_path);
    }

    let mime = mime_guess::from_path(&path).first_or_text_plain();
    let headers = text_headers(content_type_for(&mime));

    let mut file = match fs::read(&path) {
        Ok(file) => file,
        Err(err) => {
            if err.kind() == IoErrorKind::NotFound && is_accessing_dir {
                let html = index_listing_html(uri_path, root, &path);
                return (
                    StatusCode::OK,
                    text_headers("text/html; charset=utf-8"),
                    Body::from(html),
                    access_target,
                );
            }

            let status = match err.kind() {
                IoErrorKind::NotFound => StatusCode::NOT_FOUND,
                _ => StatusCode::INTERNAL_SERVER_ERROR,
            };

            return (
                status,
                headers,
                if mime == "text/html" {
                    Body::from(error_html(&err.to_string(), is_reload))
                } else {
                    Body::from(err.to_string())
                },
                access_target,
            );
        }
    };

    if mime == "text/html" {
        let text = match String::from_utf8(file) {
            Ok(text) => text,
            Err(err) => {
                return (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    headers,
                    Body::from(error_html(&err.to_string(), is_reload)),
                    access_target,
                );
            }
        };
        file = format!("{text}{}", format_script(is_reload)).into_bytes();
    }

    (StatusCode::OK, headers, Body::from(file), access_target)
}

fn sanitize_uri_path(uri_path: &str) -> Option<PathBuf> {
    let path = uri_path.trim_start_matches('/');
    if path.is_empty() {
        return Some(PathBuf::new());
    }

    let candidate = Path::new(path);
    if candidate.components().any(|component| {
        matches!(
            component,
            Component::ParentDir | Component::Prefix(_) | Component::RootDir
        )
    }) {
        return None;
    }

    Some(candidate.to_path_buf())
}

fn content_type_for(mime: &mime::Mime) -> String {
    if mime.type_() == mime::TEXT {
        format!("{}; charset=utf-8", mime.as_ref())
    } else {
        mime.as_ref().to_string()
    }
}

fn text_headers(content_type: impl AsRef<str>) -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.append(
        header::CONTENT_TYPE,
        HeaderValue::from_str(content_type.as_ref()).unwrap(),
    );
    headers
}

fn format_script(is_reload: bool) -> String {
    if is_reload {
        format!("<script>{RELOAD_PAYLOAD}</script>")
    } else {
        format!(r#"<script>{WEBSOCKET_FUNCTION}(false)</script>"#)
    }
}

fn error_html(message: &str, is_reload: bool) -> String {
    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Error</title></head><body><pre>{}</pre>{}</body></html>",
        html_escape(message),
        format_script(is_reload)
    )
}

fn index_listing_html(uri_path: &str, root: &Path, index_path: &Path) -> String {
    let dir = index_path.parent().unwrap_or(root);
    let mut entries = fs::read_dir(dir)
        .ok()
        .into_iter()
        .flat_map(|items| items.filter_map(Result::ok))
        .filter_map(|entry| {
            let is_dir = entry.metadata().ok()?.is_dir();
            let trailing = if is_dir { "/" } else { "" };
            entry
                .file_name()
                .to_str()
                .map(|name| format!("{name}{trailing}"))
        })
        .collect::<Vec<_>>();

    entries.sort();
    if uri_path != "/" {
        entries.insert(0, "..".to_string());
    }

    let items = entries
        .into_iter()
        .map(|entry| format!("<li><a href=\"{0}\">{0}</a></li>", html_escape(&entry)))
        .collect::<Vec<_>>()
        .join("\n");

    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Index of {}</title></head><body><h1>Index of {}</h1><ul>{}</ul>{}</body></html>",
        html_escape(uri_path),
        html_escape(uri_path),
        items,
        format_script(false)
    )
}

fn html_escape(input: &str) -> String {
    input
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn log_access(method: &Method, uri_path: &str, status: StatusCode, target: Option<&str>) {
    if status.is_server_error() {
        log::error!("{}", format_access_message(method, uri_path, status, target));
    } else if status.is_client_error() {
        log::warn!("{}", format_access_message(method, uri_path, status, target));
    } else {
        log::info!("{}", format_access_message(method, uri_path, status, target));
    }
}

fn format_access_message(
    method: &Method,
    uri_path: &str,
    status: StatusCode,
    target: Option<&str>,
) -> String {
    let mut message = format!("{method} {uri_path} -> {}", status.as_u16());
    if let Some(reason) = status.canonical_reason() {
        message.push(' ');
        message.push_str(reason);
    }
    if let Some(target) = target {
        message.push_str(" (");
        message.push_str(target);
        message.push(')');
    }
    message
}

async fn create_recommended_watcher() -> Result<
    (
        Debouncer<RecommendedWatcher, RecommendedCache>,
        Receiver<Result<Vec<DebouncedEvent>, Vec<Error>>>,
    ),
> {
    let rt = Handle::current();
    let (tx, rx) = channel::<Result<Vec<DebouncedEvent>, Vec<Error>>>(16);

    new_debouncer(
        Duration::from_millis(200),
        None,
        move |result: DebounceEventResult| {
            let tx = tx.clone();
            rt.spawn(async move {
                let _ = tx.send(result).await;
            });
        },
    )
    .map(|debouncer| (debouncer, rx))
    .map_err(|error| anyhow!("litesite: failed to create file watcher: {error}"))
}

async fn watch_for_changes(
    root: PathBuf,
    mut debouncer: Debouncer<RecommendedWatcher, RecommendedCache>,
    mut rx: Receiver<Result<Vec<DebouncedEvent>, Vec<Error>>>,
    tx: Arc<broadcast::Sender<()>>,
) {
    if let Err(error) = debouncer.watch(&root, RecursiveMode::Recursive) {
        log::error!("Watch failed: {error}");
        return;
    }
    log::info!("Start watching changes");

    while let Some(result) = rx.recv().await {
        let mut changed = false;

        match result {
            Ok(events) => {
                for event in events {
                    if let Some(message) = describe_change(&root, &event) {
                        log::info!("{message}");
                        changed = true;
                    }
                }
            }
            Err(errors) => {
                for error in errors {
                    log::error!("Watch error: {error}");
                }
            }
        }

        if changed {
            log::info!("Reload 1 waiters");
            let _ = tx.send(());
        }
    }
}

fn describe_change(root: &Path, event: &DebouncedEvent) -> Option<String> {
    match &event.event.kind {
        EventKind::Create(_) => event
            .event
            .paths
            .first()
            .map(|path| format!("Change detected: {}", display_change_path(root, path))),
        EventKind::Modify(modify) => {
            if let notify::event::ModifyKind::Name(notify::event::RenameMode::Both) = modify {
                match (event.event.paths.first(), event.event.paths.get(1)) {
                    (Some(from), Some(to)) => Some(format!(
                        "Change detected: {} -> {}",
                        display_change_path(root, from),
                        display_change_path(root, to)
                    )),
                    _ => None,
                }
            } else {
                event.event.paths.first().map(|path| {
                    format!("Change detected: {}", display_change_path(root, path))
                })
            }
        }
        EventKind::Remove(_) => event
            .event
            .paths
            .first()
            .map(|path| format!("Change detected: {}", display_change_path(root, path))),
        _ => None,
    }
}

fn display_change_path(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .map(display_relative_path)
        .unwrap_or_else(|_| path.display().to_string())
}

fn display_relative_path(path: &Path) -> String {
    if path.as_os_str().is_empty() {
        ".".to_string()
    } else {
        format!("./{}", path.display())
    }
}

fn format_root_display(root: &Path, public: &Path) -> String {
    public
        .strip_prefix(root)
        .map(display_relative_path)
        .unwrap_or_else(|_| public.display().to_string())
}

fn init_logger() {
    LOGGER_INIT.call_once(|| {
        let mut builder = colog::basic_builder();
        builder.filter(None, LevelFilter::Info);
        if let Ok(rust_log) = env::var("RUST_LOG") {
            builder.parse_filters(&rust_log);
        }
        builder.format(|buf, record| write_log_record(buf, record));
        let _ = builder.try_init();
    });
}

fn write_log_record(buf: &mut Formatter, record: &Record<'_>) -> std::io::Result<()> {
    writeln!(buf, "{}", format_record(record))
}

fn format_record(record: &Record<'_>) -> String {
    let level = match record.level() {
        Level::Error => LogLevel::Error,
        Level::Warn => LogLevel::Warn,
        _ => LogLevel::Info,
    };
    let file = record.file().unwrap_or("serve.rs");
    let line = record.line().unwrap_or(0);
    let message = record.args().to_string();
    format_log_record(level, file, line, &message)
}

fn format_log_record(level: LogLevel, file: &str, line: u32, message: &str) -> String {
    let now = chrono::Local::now().format("%y%m%d %H:%M:%S");
    let module = Path::new(file)
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("serve");
    let prefix = format!("[{} {now} {module}:{line}]", level.code());
    let prefix = colorize_prefix(level, prefix);
    format!("{prefix} {}", indent_newlines(message))
}

fn colorize_prefix(level: LogLevel, prefix: String) -> Cow<'static, str> {
    if !std::io::stderr().is_terminal() || env::var_os("NO_COLOR").is_some() {
        return Cow::Owned(prefix);
    }

    Cow::Owned(format!("{}{}{}", level.ansi_code(), prefix, "\x1b[0m"))
}

fn indent_newlines(message: &str) -> String {
    message.replace('\n', "\n    ")
}

impl LogLevel {
    fn code(self) -> char {
        match self {
            LogLevel::Info => 'I',
            LogLevel::Warn => 'W',
            LogLevel::Error => 'E',
        }
    }

    fn ansi_code(self) -> &'static str {
        match self {
            LogLevel::Info => "\x1b[2;32m",
            LogLevel::Warn => "\x1b[2;33m",
            LogLevel::Error => "\x1b[2;31m",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        display_relative_path, format_access_message, format_log_record, format_root_display,
        sanitize_uri_path, LogLevel,
    };
    use axum::http::{Method, StatusCode};
    use std::path::Path;

    #[test]
    fn root_display_is_relative() {
        let root = Path::new("/tmp/site");
        let public = root.join("src/public");
        assert_eq!(format_root_display(root, &public), "./src/public");
    }

    #[test]
    fn relative_display_for_empty_path_is_dot() {
        assert_eq!(display_relative_path(Path::new("")), ".");
    }

    #[test]
    fn parent_segments_are_rejected() {
        assert!(sanitize_uri_path("/../secret").is_none());
        assert!(sanitize_uri_path("/ok/path").is_some());
    }

    #[test]
    fn access_message_includes_status_and_target() {
        assert_eq!(
            format_access_message(
                &Method::GET,
                "/style.css",
                StatusCode::OK,
                Some("./style.css"),
            ),
            "GET /style.css -> 200 OK (./style.css)"
        );
    }

    #[test]
    fn log_record_uses_tornado_style_prefix() {
        let line = 42;
        let formatted = format_log_record(LogLevel::Info, "src/serve.rs", line, "Serving on");
        assert!(formatted.contains("[I "));
        assert!(formatted.contains(" serve:42] Serving on"));
    }
}
