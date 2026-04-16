import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_item.dart';
import '../rust/api/downloader.dart' as bridge;
import '../rust/api/types.dart';
import 'settings_provider.dart';

class DownloadsNotifier extends StateNotifier<List<DownloadItem>> {
  DownloadsNotifier(this._ref) : super([]);

  final Ref _ref;
  final Map<String, StreamSubscription<DownloadEvent>> _subs = {};

  // ---- public API ----------------------------------------------------------

  /// Enqueue a URL: immediately show a card and fetch metadata.
  void enqueue(String url) {
    final id = _newId();
    final item = DownloadItem(
      id: id,
      url: url,
      title: url,
      status: DownloadStatus.fetching,
      addedAt: DateTime.now(),
    );
    state = [...state, item];
    _fetchInfo(id, url);
  }

  /// Called when the user confirmed a format in the format-picker.
  Future<void> startDownload(
    String id,
    String formatId,
    String outputDir,
  ) async {
    final item = _find(id);
    if (item == null) return;

    _update(id, (i) => i.copyWith(
          formatId: formatId,
          outputDir: outputDir,
          status: DownloadStatus.starting,
        ));

    final settings = _ref.read(settingsProvider);
    final stream = bridge.startDownload(
      downloadId: id,
      url: item.url,
      formatId: formatId,
      outputDir: outputDir,
      ytdlpPath: settings.ytdlpPath,
    );

    _subs[id] = stream.listen(
      _handleEvent,
      onError: (Object e) {
        _update(id, (i) => i.copyWith(
              status: DownloadStatus.error,
              errorMessage: e.toString(),
            ));
        _subs.remove(id);
      },
      onDone: () => _subs.remove(id),
    );
  }

  /// Cancel an active download.
  Future<void> cancel(String id) async {
    await _subs[id]?.cancel();
    _subs.remove(id);
    await bridge.cancelDownload(downloadId: id);
    _update(id, (i) => i.copyWith(status: DownloadStatus.cancelled));
  }

  /// Remove a finished/cancelled/errored item from the list.
  void remove(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  /// Remove all completed items at once.
  void clearCompleted() {
    state = state.where((i) => !i.isDone).toList();
  }

  // ---- internal ------------------------------------------------------------

  Future<void> _fetchInfo(String id, String url) async {
    final settings = _ref.read(settingsProvider);
    try {
      final info = await bridge.fetchMediaInfo(
        url: url,
        ytdlpPath: settings.ytdlpPath,
      );
      _update(id, (i) => i.copyWith(
            title: info.title,
            status: DownloadStatus.pickingFormat,
            mediaInfo: info,
          ));
    } catch (e) {
      _update(id, (i) => i.copyWith(
            status: DownloadStatus.error,
            errorMessage: e.toString(),
          ));
    }
  }

  void _handleEvent(DownloadEvent event) {
    final id = event.downloadId;
    switch (event.status) {
      case 'starting':
        _update(id, (i) => i.copyWith(status: DownloadStatus.starting));
      case 'downloading':
        _update(id, (i) => i.copyWith(
              status: DownloadStatus.downloading,
              percent: event.percent,
              speed: event.speed,
              eta: event.eta,
              downloaded: event.downloaded,
              total: event.total,
            ));
      case 'merging':
        _update(id, (i) => i.copyWith(
              status: DownloadStatus.merging,
              percent: 100.0,
            ));
      case 'completed':
        _update(id, (i) => i.copyWith(
              status: DownloadStatus.completed,
              percent: 100.0,
              filePath: event.filePath,
            ));
      case 'error':
        _update(id, (i) => i.copyWith(
              status: DownloadStatus.error,
              errorMessage: event.errorMessage,
            ));
      case 'cancelled':
        _update(id, (i) => i.copyWith(status: DownloadStatus.cancelled));
    }
  }

  void _update(String id, DownloadItem Function(DownloadItem) fn) {
    state = [
      for (final item in state)
        if (item.id == id) fn(item) else item,
    ];
  }

  DownloadItem? _find(String id) {
    try {
      return state.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadItem>>(
  (ref) => DownloadsNotifier(ref),
);

/// Convenience: count of active downloads.
final activeDownloadCountProvider = Provider<int>((ref) {
  return ref.watch(downloadsProvider).where((d) => d.isActive).length;
});
