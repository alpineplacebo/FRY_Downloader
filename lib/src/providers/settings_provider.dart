import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String ytdlpPath;
  final String outputDir;
  final int maxConcurrent;
  final ThemeMode themeMode;

  const AppSettings({
    this.ytdlpPath = 'yt-dlp',
    this.outputDir = '',
    this.maxConcurrent = 2,
    this.themeMode = ThemeMode.system,
  });

  AppSettings copyWith({
    String? ytdlpPath,
    String? outputDir,
    int? maxConcurrent,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      ytdlpPath: ytdlpPath ?? this.ytdlpPath,
      outputDir: outputDir ?? this.outputDir,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      ytdlpPath: prefs.getString('ytdlp_path') ?? 'yt-dlp',
      outputDir: prefs.getString('output_dir') ?? '',
      maxConcurrent: prefs.getInt('max_concurrent') ?? 2,
      themeMode: ThemeMode.values[prefs.getInt('theme_mode') ?? 0],
    );
  }

  Future<void> setYtdlpPath(String path) async {
    state = state.copyWith(ytdlpPath: path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ytdlp_path', path);
  }

  Future<void> setOutputDir(String dir) async {
    state = state.copyWith(outputDir: dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('output_dir', dir);
  }

  Future<void> setMaxConcurrent(int value) async {
    state = state.copyWith(maxConcurrent: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_concurrent', value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
