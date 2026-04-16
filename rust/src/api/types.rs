/// Info returned by yt-dlp --dump-json for a URL.
pub struct MediaInfo {
    pub id: String,
    pub title: String,
    pub uploader: Option<String>,
    /// Duration in seconds.
    pub duration: Option<f64>,
    pub thumbnail_url: Option<String>,
    pub webpage_url: String,
    pub formats: Vec<FormatEntry>,
}

/// A single downloadable format entry.
pub struct FormatEntry {
    pub format_id: String,
    pub ext: String,
    /// Human-readable label, e.g. "1080p (mp4)", "Audio only (m4a)".
    pub display_name: String,
    pub resolution: Option<String>,
    pub fps: Option<f64>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    /// Exact filesize in bytes if known.
    pub filesize: Option<i64>,
    /// Approximate filesize in bytes.
    pub filesize_approx: Option<i64>,
    /// Total bitrate kbps.
    pub tbr: Option<f64>,
    pub is_audio_only: bool,
    pub is_video_only: bool,
}

/// An event emitted while a download is in progress.
pub struct DownloadEvent {
    pub download_id: String,
    pub status: String,
    /// 0.0 – 100.0
    pub percent: f64,
    /// Human-readable speed, e.g. "1.23 MiB/s"
    pub speed: String,
    /// Human-readable ETA, e.g. "00:04"
    pub eta: String,
    /// Human-readable amount downloaded, e.g. "5.00MiB"
    pub downloaded: String,
    /// Human-readable total size, e.g. "10.00MiB"
    pub total: String,
    /// Set on completion.
    pub file_path: Option<String>,
    /// Set on error.
    pub error_message: Option<String>,
}
