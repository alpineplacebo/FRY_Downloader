import '../rust/api/types.dart';

enum DownloadStatus {
  fetching,
  pickingFormat,
  starting,
  downloading,
  merging,
  completed,
  error,
  cancelled,
}

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String? formatId;
  final String? outputDir;
  final DownloadStatus status;
  final double percent;
  final String speed;
  final String eta;
  final String downloaded;
  final String total;
  final String? filePath;
  final String? errorMessage;
  final MediaInfo? mediaInfo;
  final DateTime addedAt;

  const DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    this.formatId,
    this.outputDir,
    required this.status,
    this.percent = 0.0,
    this.speed = '',
    this.eta = '',
    this.downloaded = '',
    this.total = '',
    this.filePath,
    this.errorMessage,
    this.mediaInfo,
    required this.addedAt,
  });

  bool get isActive =>
      status == DownloadStatus.fetching ||
      status == DownloadStatus.starting ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.merging;

  bool get isDone =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.error ||
      status == DownloadStatus.cancelled;

  DownloadItem copyWith({
    String? title,
    String? formatId,
    String? outputDir,
    DownloadStatus? status,
    double? percent,
    String? speed,
    String? eta,
    String? downloaded,
    String? total,
    String? filePath,
    String? errorMessage,
    MediaInfo? mediaInfo,
  }) {
    return DownloadItem(
      id: id,
      url: url,
      title: title ?? this.title,
      formatId: formatId ?? this.formatId,
      outputDir: outputDir ?? this.outputDir,
      status: status ?? this.status,
      percent: percent ?? this.percent,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      downloaded: downloaded ?? this.downloaded,
      total: total ?? this.total,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      addedAt: addedAt,
    );
  }
}
