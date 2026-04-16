use std::collections::HashMap;
use std::sync::Mutex;

use anyhow::Context;
use once_cell::sync::Lazy;
use regex::Regex;
use serde_json::Value;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::{Child, Command};

use crate::frb_generated::StreamSink;

use super::types::*;

// ---------------------------------------------------------------------------
// Global process registry — maps download_id to the running yt-dlp child.
// The MutexGuard must never be held across an .await point.
// ---------------------------------------------------------------------------

static PROCESSES: Lazy<Mutex<HashMap<String, Child>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Initialise the Flutter-Rust bridge runtime. Must be called once from Dart
/// before any other API function.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Return the installed yt-dlp version string, or an error message.
pub async fn get_ytdlp_version(ytdlp_path: String) -> Result<String, String> {
    let output = Command::new(&ytdlp_path)
        .arg("--version")
        .output()
        .await
        .map_err(|e| format!("Failed to run yt-dlp: {e}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
    }
}

/// Fetch metadata (title, formats, …) for the given URL.
pub async fn fetch_media_info(
    url: String,
    ytdlp_path: String,
) -> Result<MediaInfo, String> {
    let output = Command::new(&ytdlp_path)
        .args(["--dump-json", "--no-playlist", "--no-warnings", &url])
        .output()
        .await
        .map_err(|e| format!("Failed to launch yt-dlp: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("yt-dlp error: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_media_info(&stdout).map_err(|e| e.to_string())
}

/// Start downloading a URL with the given format.
///
/// Progress events are streamed via `sink` until completion, cancellation, or
/// an error. The download can be cancelled by calling [`cancel_download`] with
/// the same `download_id`.
pub async fn start_download(
    download_id: String,
    url: String,
    format_id: String,
    output_dir: String,
    ytdlp_path: String,
    sink: StreamSink<DownloadEvent>,
) {
    let output_template =
        format!("{}/%(title)s.%(ext)s", output_dir.trim_end_matches(['/', '\\']));

    let mut child = match Command::new(&ytdlp_path)
        .args([
            "--format",
            &format_id,
            "--output",
            &output_template,
            "--newline",
            "--progress",
            "--no-playlist",
            "--no-warnings",
            "--merge-output-format",
            "mp4",
            &url,
        ])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            let _ = sink.add(error_event(&download_id, format!("Failed to launch yt-dlp: {e}")));
            return;
        }
    };

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();

    // Store the child — drop the guard immediately after insertion.
    {
        PROCESSES.lock().unwrap().insert(download_id.clone(), child);
    }

    let _ = sink.add(DownloadEvent {
        download_id: download_id.clone(),
        status: "starting".into(),
        percent: 0.0,
        speed: String::new(),
        eta: String::new(),
        downloaded: String::new(),
        total: String::new(),
        file_path: None,
        error_message: None,
    });

    // Regexes for yt-dlp stdout lines.
    let re_progress = Regex::new(
        r"\[download\]\s+([\d.]+)%\s+of\s+~?\s*(\S+)\s+at\s+(\S+)\s+ETA\s+(\S+)",
    )
    .unwrap();
    let re_merging = Regex::new(r"\[Merger\]").unwrap();
    let re_dest = Regex::new(r"\[download\] Destination: (.+)").unwrap();
    let re_already =
        Regex::new(r"\[download\] (.+) has already been downloaded").unwrap();

    let mut lines = BufReader::new(stdout).lines();
    let mut last_file: Option<String> = None;

    while let Ok(Some(line)) = lines.next_line().await {
        if let Some(caps) = re_progress.captures(&line) {
            let percent: f64 = caps[1].parse().unwrap_or(0.0);
            let total = caps[2].to_string();
            let speed = caps[3].to_string();
            let eta = caps[4].to_string();
            let downloaded = format_downloaded(percent, &total);

            let _ = sink.add(DownloadEvent {
                download_id: download_id.clone(),
                status: "downloading".into(),
                percent,
                speed,
                eta,
                downloaded,
                total,
                file_path: None,
                error_message: None,
            });
        } else if re_merging.is_match(&line) {
            let _ = sink.add(DownloadEvent {
                download_id: download_id.clone(),
                status: "merging".into(),
                percent: 100.0,
                speed: String::new(),
                eta: String::new(),
                downloaded: String::new(),
                total: String::new(),
                file_path: None,
                error_message: None,
            });
        } else if let Some(caps) = re_dest.captures(&line) {
            last_file = Some(caps[1].trim().to_string());
        } else if let Some(caps) = re_already.captures(&line) {
            last_file = Some(caps[1].trim().to_string());
        }
    }

    // Remove the child from the map — do NOT hold the guard across the
    // following .await.
    let maybe_child = {
        let mut map = PROCESSES.lock().unwrap();
        map.remove(&download_id)
    };

    let Some(mut child) = maybe_child else {
        // No child in map means cancel_download() already killed it.
        let _ = sink.add(DownloadEvent {
            download_id: download_id.clone(),
            status: "cancelled".into(),
            percent: 0.0,
            speed: String::new(),
            eta: String::new(),
            downloaded: String::new(),
            total: String::new(),
            file_path: None,
            error_message: None,
        });
        return;
    };

    match child.wait().await {
        Ok(status) if status.success() => {
            let _ = sink.add(DownloadEvent {
                download_id,
                status: "completed".into(),
                percent: 100.0,
                speed: String::new(),
                eta: String::new(),
                downloaded: String::new(),
                total: String::new(),
                file_path: last_file,
                error_message: None,
            });
        }
        _ => {
            let mut err_buf = String::new();
            let mut err_lines = BufReader::new(stderr).lines();
            while let Ok(Some(l)) = err_lines.next_line().await {
                err_buf.push_str(&l);
                err_buf.push('\n');
            }
            let _ = sink.add(error_event(&download_id, err_buf.trim().to_string()));
        }
    }
}

/// Cancel a running download. Returns `true` if the process was found and
/// killed, `false` if no download with that ID was active.
pub async fn cancel_download(download_id: String) -> bool {
    // Remove the child from the map first — guard dropped before .await.
    let maybe_child = {
        let mut map = PROCESSES.lock().unwrap();
        map.remove(&download_id)
    };
    if let Some(mut child) = maybe_child {
        let _ = child.kill().await;
        true
    } else {
        false
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn error_event(id: &str, msg: String) -> DownloadEvent {
    DownloadEvent {
        download_id: id.to_string(),
        status: "error".into(),
        percent: 0.0,
        speed: String::new(),
        eta: String::new(),
        downloaded: String::new(),
        total: String::new(),
        file_path: None,
        error_message: Some(msg),
    }
}

fn parse_media_info(json: &str) -> anyhow::Result<MediaInfo> {
    let v: Value = serde_json::from_str(json).context("Invalid JSON from yt-dlp")?;

    let id = v["id"].as_str().unwrap_or("").to_string();
    let title = v["title"].as_str().unwrap_or("Unknown").to_string();
    let uploader = v["uploader"].as_str().map(String::from);
    let duration = v["duration"].as_f64();
    let thumbnail_url = v["thumbnail"].as_str().map(String::from);
    let webpage_url = v["webpage_url"].as_str().unwrap_or("").to_string();

    let formats = v["formats"]
        .as_array()
        .map(|arr| arr.iter().filter_map(parse_format_entry).collect())
        .unwrap_or_default();

    Ok(MediaInfo {
        id,
        title,
        uploader,
        duration,
        thumbnail_url,
        webpage_url,
        formats,
    })
}

fn parse_format_entry(v: &Value) -> Option<FormatEntry> {
    let format_id = v["format_id"].as_str()?.to_string();
    let ext = v["ext"].as_str().unwrap_or("?").to_string();
    let vcodec = v["vcodec"].as_str().map(String::from);
    let acodec = v["acodec"].as_str().map(String::from);
    let resolution = v["resolution"].as_str().map(String::from);
    let fps = v["fps"].as_f64();
    let filesize = v["filesize"].as_i64();
    let filesize_approx = v["filesize_approx"].as_i64();
    let tbr = v["tbr"].as_f64();
    let format_note = v["format_note"].as_str().map(String::from);

    let no_video = vcodec.as_deref().map_or(false, |c| c == "none");
    let no_audio = acodec.as_deref().map_or(false, |c| c == "none");
    let is_audio_only = no_video && !no_audio;
    let is_video_only = !no_video && no_audio;

    let display_name = build_display_name(
        &format_note,
        &resolution,
        fps,
        &ext,
        is_audio_only,
        filesize.or(filesize_approx),
    );

    Some(FormatEntry {
        format_id,
        ext,
        display_name,
        resolution,
        fps,
        vcodec,
        acodec,
        filesize,
        filesize_approx,
        tbr,
        is_audio_only,
        is_video_only,
    })
}

fn build_display_name(
    note: &Option<String>,
    resolution: &Option<String>,
    fps: Option<f64>,
    ext: &str,
    is_audio_only: bool,
    size: Option<i64>,
) -> String {
    let size_str = size.map(human_bytes).unwrap_or_default();

    if is_audio_only {
        let base = note.as_deref().unwrap_or("Audio only");
        return if size_str.is_empty() {
            format!("{base} ({ext})")
        } else {
            format!("{base} ({ext}) — {size_str}")
        };
    }

    let res = resolution.as_deref().unwrap_or("");
    let fps_str = fps
        .filter(|&f| f > 0.0)
        .map(|f| format!("{f:.0}fps"))
        .unwrap_or_default();

    let label = match (res, fps_str.as_str()) {
        ("", "") => note.as_deref().unwrap_or("?").to_string(),
        (r, "") => r.to_string(),
        ("", f) => f.to_string(),
        (r, f) => format!("{r} {f}"),
    };

    if size_str.is_empty() {
        format!("{label} ({ext})")
    } else {
        format!("{label} ({ext}) — {size_str}")
    }
}

fn human_bytes(bytes: i64) -> String {
    const KB: i64 = 1024;
    const MB: i64 = KB * 1024;
    const GB: i64 = MB * 1024;
    if bytes >= GB {
        format!("{:.1} GiB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MiB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KiB", bytes as f64 / KB as f64)
    } else {
        format!("{bytes} B")
    }
}

fn format_downloaded(percent: f64, total: &str) -> String {
    let re = Regex::new(r"([\d.]+)(KiB|MiB|GiB|KB|MB|GB)").unwrap();
    if let Some(caps) = re.captures(total) {
        let num: f64 = caps[1].parse().unwrap_or(0.0);
        let unit = &caps[2];
        let done = num * percent / 100.0;
        format!("{done:.2}{unit}")
    } else {
        format!("{percent:.1}%")
    }
}
