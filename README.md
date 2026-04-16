# FRY Downloader

A high-performance, cross-platform media downloader powered by **yt-dlp**, built with a **Flutter / Dart** frontend (Material Design 3) and a **Rust** backend connected via **flutter_rust_bridge v2**.

## Features

- Paste any yt-dlp-supported URL (YouTube, SoundCloud, Twitch, …)
- Fetch available formats with a single click
- Choose exact quality / codec / audio-only before downloading
- Real-time progress bar with speed and ETA
- Download queue with cancellation support
- Download history for the session
- Configurable yt-dlp path, output folder, and concurrent download limit
- System / Light / Dark theme toggle (M3)

## Requirements

| Dependency | Notes |
|---|---|
| [Flutter ≥ 3.22](https://flutter.dev) | Windows desktop target |
| [Rust ≥ 1.75](https://rustup.rs) | Stable toolchain |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Must be on `PATH` or configured in Settings |

## Getting started

```bash
# 1. Clone the repo
git clone https://github.com/alpineplacebo/fry_downloader.git
cd fry_downloader

# 2. Install Dart/Flutter dependencies
flutter pub get

# 3. Regenerate the flutter_rust_bridge bindings (if you change Rust API)
flutter_rust_bridge_codegen generate

# 4. Build and run (Windows)
flutter run -d windows
# or
flutter build windows --release
```

The compiled `.exe` and the Rust DLL will be placed in `build/windows/x64/runner/Release/`.

## Project structure

```
FRY_Downloader/
├── lib/
│   ├── main.dart              # App entry point
│   ├── app.dart               # MaterialApp + M3 theme
│   └── src/
│       ├── rust/              # Auto-generated bridge (flutter_rust_bridge)
│       ├── models/            # Dart data models
│       ├── providers/         # Riverpod state management
│       └── screens/           # UI screens & widgets
├── rust/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       └── api/
│           ├── downloader.rs  # yt-dlp process management & progress streaming
│           └── types.rs       # Shared data types (MediaInfo, FormatEntry, …)
├── windows/                   # Flutter Windows runner (CMake / MSVC)
└── flutter_rust_bridge.yaml   # Bridge codegen configuration
```

## Architecture

```
Flutter UI (Dart)
    │  Riverpod providers
    ▼
flutter_rust_bridge (auto-generated FFI)
    │  Dart ↔ Rust calls & streams
    ▼
Rust backend
    │  tokio async runtime
    ▼
yt-dlp subprocess
    │  stdout parsing (progress %, speed, ETA)
    ▼
File system (downloaded media)
```
