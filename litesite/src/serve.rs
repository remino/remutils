use anyhow::{Context, Result, anyhow};
use axum::body::Body;
use axum::extract::{Request, State};
use axum::http::{HeaderMap, HeaderValue, Method, StatusCode, header};
use axum::response::IntoResponse;
use axum::response::sse::{Event, KeepAlive, Sse};
use axum::routing::get;
use axum::{Router, serve};
use env_logger::fmt::Formatter;
use futures::StreamExt;
use futures::stream;
use log::{Level, LevelFilter, Record};
use mime_guess::mime;
use notify::{Error, RecommendedWatcher, RecursiveMode};
use notify_debouncer_full::{
    DebounceEventResult, DebouncedEvent, Debouncer, RecommendedCache, new_debouncer,
};
use std::borrow::Cow;
use std::convert::Infallible;
use std::env;
use std::fs;
use std::io::ErrorKind as IoErrorKind;
use std::io::IsTerminal;
use std::io::Write;
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Once};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::net::TcpListener;
use tokio::runtime::Handle;
use tokio::sync::broadcast;
use tokio::sync::mpsc::{Receiver, channel};
use tokio_stream::wrappers::BroadcastStream;

const SSE_PATH: &str = "/__litesite/livereload";
const WORKER_PATH: &str = "/__litesite/livereload-worker.js";
const CLIENT_SNIPPET: &str = include_str!("serve_livereload_client.html");
const WORKER_JS: &str = include_str!("serve_livereload_worker.js");
static LOGGER_INIT: Once = Once::new();

struct AppState {
    root: PathBuf,
    bus: Arc<broadcast::Sender<String>>,
    boot_id: String,
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

    let (bus, _) = broadcast::channel(16);
    let bus = Arc::new(bus);
    let boot_id = current_boot_id();

    log::info!("Serving on http://127.0.0.1:{}", local_addr.port());
    log::info!("Root: {public_display}");
    log::info!("Listening on http://{}:{}", local_addr.ip(), local_addr.port());
    log::info!("SSE endpoint {SSE_PATH}");
    log::info!("Press Ctrl-C to stop.");

    let state = Arc::new(AppState {
        root: serve_root.clone(),
        bus: bus.clone(),
        boot_id,
    });

    let (debouncer, rx) = create_recommended_watcher().await?;
    let watcher = tokio::spawn(watch_for_changes(serve_root, debouncer, rx, bus));

    let router = Router::new()
        .route(SSE_PATH, get(sse_handler))
        .route(WORKER_PATH, get(worker_handler))
        .route("/", get(static_assets))
        .route("/{*path}", get(static_assets))
        .with_state(state);

    let result = serve(listener, router).await;
    watcher.abort();

    result.map_err(|error| anyhow!("litesite: preview server failed: {error}"))
}

async fn sse_handler(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let hello_state = state.clone();
    let hello = stream::once(async move {
        Ok::<_, Infallible>(Event::default().event("hello").data(hello_state.boot_id.clone()))
    });

    let updates = BroadcastStream::new(state.bus.subscribe()).filter_map(|message| async move {
        message
            .ok()
            .map(|data| Ok::<_, Infallible>(Event::default().event("change").data(data)))
    });

    Sse::new(hello.chain(updates)).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keep-alive"),
    )
}

async fn worker_handler() -> impl IntoResponse {
    (
        [(
            header::CONTENT_TYPE,
            "application/javascript; charset=utf-8",
        )],
        WORKER_JS,
    )
}

async fn static_assets(
    State(state): State<Arc<AppState>>,
    req: Request<Body>,
) -> (StatusCode, HeaderMap, Body) {
    let method = req.method().clone();
    let uri_path = req.uri().path().to_string();
    let response = serve_request(&state.root, &uri_path);
    log_access(&method, &uri_path, response.0, response.3.as_deref());
    (response.0, response.1, response.2)
}

fn serve_request(root: &Path, uri_path: &str) -> (StatusCode, HeaderMap, Body, Option<String>) {
    if uri_path.starts_with("//") {
        let redirect = format!("/{}", uri_path.trim_start_matches('/'));
        let mut headers = no_store_headers();
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
            let mut headers = no_store_headers();
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

    let file = match fs::read(&path) {
        Ok(file) => file,
        Err(err) => {
            if err.kind() == IoErrorKind::NotFound && is_accessing_dir {
                let html = inject_client(&index_listing_html(uri_path, root, &path));
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
                    Body::from(inject_client(&error_html(&err.to_string())))
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
                    Body::from(inject_client(&error_html(&err.to_string()))),
                    access_target,
                );
            }
        };

        return (
            StatusCode::OK,
            headers,
            Body::from(inject_client(&text)),
            access_target,
        );
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

fn no_store_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("no-store, must-revalidate"),
    );
    headers
}

fn text_headers(content_type: impl AsRef<str>) -> HeaderMap {
    let mut headers = no_store_headers();
    headers.append(
        header::CONTENT_TYPE,
        HeaderValue::from_str(content_type.as_ref()).unwrap(),
    );
    headers
}

fn error_html(message: &str) -> String {
    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Error</title></head><body><pre>{}</pre></body></html>",
        html_escape(message)
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
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Index of {}</title></head><body><h1>Index of {}</h1><ul>{}</ul></body></html>",
        html_escape(uri_path),
        html_escape(uri_path),
        items,
    )
}

fn inject_client(html: &str) -> String {
    if let Some(index) = html.rfind("</body>") {
        let mut output = String::with_capacity(html.len() + CLIENT_SNIPPET.len());
        output.push_str(&html[..index]);
        output.push_str(CLIENT_SNIPPET);
        output.push_str(&html[index..]);
        output
    } else {
        let mut output = String::with_capacity(html.len() + CLIENT_SNIPPET.len());
        output.push_str(html);
        output.push_str(CLIENT_SNIPPET);
        output
    }
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
    bus: Arc<broadcast::Sender<String>>,
) {
    if let Err(error) = debouncer.watch(&root, RecursiveMode::Recursive) {
        log::error!("Watch failed: {error}");
        return;
    }
    log::info!("Start watching changes");

    while let Some(result) = rx.recv().await {
        match result {
            Ok(events) => {
                let mut css_only = false;
                let mut saw_change = false;
                let mut saw_reload_type = false;

                for event in events {
                    for path in &event.event.paths {
                        match classify(path) {
                            Some(ChangeKind::Css) => {
                                log::info!("Change detected: {}", display_change_path(&root, path));
                                if !saw_change {
                                    css_only = true;
                                }
                                saw_change = true;
                            }
                            Some(ChangeKind::Reload) => {
                                log::info!("Change detected: {}", display_change_path(&root, path));
                                saw_change = true;
                                saw_reload_type = true;
                                css_only = false;
                            }
                            None => {}
                        }
                    }
                }

                if saw_change {
                    let payload = if css_only && !saw_reload_type {
                        r#"{"type":"css"}"#
                    } else {
                        r#"{"type":"reload"}"#
                    };
                    log::info!("Reload {} waiters", bus.receiver_count());
                    let _ = bus.send(payload.to_string());
                }
            }
            Err(errors) => {
                for error in errors {
                    log::error!("Watch error: {error}");
                }
            }
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ChangeKind {
    Css,
    Reload,
}

fn classify(path: &Path) -> Option<ChangeKind> {
    let path_str = path.to_string_lossy();
    if path_str.ends_with('~')
        || path_str.contains(".swp")
        || path_str.contains(".swx")
        || path_str.contains(".tmp")
        || path_str.contains("/.git/")
        || path_str.contains("/.hg/")
        || path_str.contains("/node_modules/")
        || path_str.contains("/target/")
        || path_str.contains("/.idea/")
        || path_str.contains("/.vscode/")
    {
        return None;
    }

    match path
        .extension()
        .and_then(|value| value.to_str())
        .map(|value| value.to_ascii_lowercase())
        .as_deref()
    {
        Some("css") => Some(ChangeKind::Css),
        Some("rs") | Some("lock") | Some("rlib") | Some("rmeta") | Some("d") | None => None,
        _ => Some(ChangeKind::Reload),
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

fn current_boot_id() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos().to_string())
        .unwrap_or_else(|_| "dev".to_string())
}

fn init_logger() {
    LOGGER_INIT.call_once(|| {
        let mut builder = colog::basic_builder();
        builder.filter(None, LevelFilter::Info);
        if let Ok(rust_log) = env::var("RUST_LOG") {
            builder.parse_filters(&rust_log);
        }
        builder.format(write_log_record);
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
        ChangeKind, CLIENT_SNIPPET, WORKER_JS, display_relative_path, format_access_message,
        format_log_record, format_root_display, inject_client, sanitize_uri_path, classify,
        LogLevel, SSE_PATH, WORKER_PATH,
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
        let formatted = format_log_record(LogLevel::Info, "src/serve.rs", 42, "Serving on");
        assert!(formatted.contains("[I "));
        assert!(formatted.contains(" serve:42] Serving on"));
    }

    #[test]
    fn injects_before_closing_body() {
        let html = "<html><body><h1>hi</h1></body></html>";
        let output = inject_client(html);
        assert!(output.contains("data-litesite-livereload"));
        assert!(output.find("data-litesite-livereload").unwrap() < output.find("</body>").unwrap());
    }

    #[test]
    fn client_prefers_shared_worker_with_eventsource_fallback() {
        assert!(CLIENT_SNIPPET.contains("SharedWorker"));
        assert!(CLIENT_SNIPPET.contains(WORKER_PATH));
        let worker_at = CLIENT_SNIPPET.find("SharedWorker").unwrap();
        let fallback_at = CLIENT_SNIPPET.find("new EventSource").unwrap();
        assert!(worker_at < fallback_at);
    }

    #[test]
    fn worker_holds_single_eventsource_and_fans_out() {
        assert_eq!(WORKER_JS.matches("new EventSource").count(), 1);
        assert!(WORKER_JS.contains("onconnect"));
        assert!(WORKER_JS.contains("broadcast"));
        assert!(WORKER_JS.contains(SSE_PATH));
    }

    #[test]
    fn classify_routes_css_vs_reload_vs_ignore() {
        assert_eq!(classify(Path::new("static/css/app.css")), Some(ChangeKind::Css));
        assert_eq!(classify(Path::new("templates/home.html")), Some(ChangeKind::Reload));
        assert_eq!(classify(Path::new("static/app.js")), Some(ChangeKind::Reload));
        assert_eq!(classify(Path::new("content/post.md")), Some(ChangeKind::Reload));
        assert_eq!(classify(Path::new("site.config.toml")), Some(ChangeKind::Reload));
        assert_eq!(classify(Path::new("src/main.rs")), None);
        assert_eq!(classify(Path::new("Cargo.lock")), None);
        assert_eq!(classify(Path::new("templates/.home.html.swp")), None);
        assert_eq!(classify(Path::new("templates/home.html~")), None);
        assert_eq!(classify(Path::new("target/debug/foo")), None);
        assert_eq!(classify(Path::new("templates")), None);
    }
}
