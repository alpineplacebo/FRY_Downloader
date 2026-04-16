import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_item.dart';
import '../../providers/downloads_provider.dart';
import 'format_picker_sheet.dart';

class DownloadItemCard extends ConsumerWidget {
  const DownloadItemCard({super.key, required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: cs.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: item.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _StatusLabel(item: item),
                    ],
                  ),
                ),
                _ActionButton(item: item),
              ],
            ),
            if (item.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 10),
              _ProgressRow(item: item),
            ],
            if (item.status == DownloadStatus.pickingFormat) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => showFormatPicker(context, ref, item),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Choose format & download'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
            if (item.status == DownloadStatus.error &&
                item.errorMessage != null) ...[
              const SizedBox(height: 8),
              _ErrorBox(message: item.errorMessage!),
            ],
            if (item.status == DownloadStatus.completed &&
                item.filePath != null) ...[
              const SizedBox(height: 8),
              _CompletedRow(filePath: item.filePath!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case DownloadStatus.fetching:
        return SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: cs.primary,
          ),
        );
      case DownloadStatus.pickingFormat:
        return Icon(Icons.tune_rounded, color: cs.secondary, size: 22);
      case DownloadStatus.starting:
        return SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: cs.tertiary,
          ),
        );
      case DownloadStatus.downloading:
        return Icon(Icons.download_rounded, color: cs.primary, size: 22);
      case DownloadStatus.merging:
        return Icon(Icons.merge_rounded, color: cs.tertiary, size: 22);
      case DownloadStatus.completed:
        return Icon(Icons.check_circle_rounded,
            color: cs.primary, size: 22);
      case DownloadStatus.error:
        return Icon(Icons.error_rounded, color: cs.error, size: 22);
      case DownloadStatus.cancelled:
        return Icon(Icons.cancel_rounded,
            color: cs.onSurfaceVariant, size: 22);
    }
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    switch (item.status) {
      case DownloadStatus.fetching:
        return Text('Fetching media info…', style: style);
      case DownloadStatus.pickingFormat:
        return Text('Ready — choose a format', style: style);
      case DownloadStatus.starting:
        return Text('Starting download…', style: style);
      case DownloadStatus.downloading:
        final parts = <String>[];
        if (item.total.isNotEmpty) parts.add(item.total);
        if (item.speed.isNotEmpty) parts.add(item.speed);
        if (item.eta.isNotEmpty) parts.add('ETA ${item.eta}');
        return Text(parts.join(' · '), style: style);
      case DownloadStatus.merging:
        return Text('Merging streams…', style: style);
      case DownloadStatus.completed:
        return Text('Completed', style: style?.copyWith(color: cs.primary));
      case DownloadStatus.error:
        return Text('Failed', style: style?.copyWith(color: cs.error));
      case DownloadStatus.cancelled:
        return Text('Cancelled', style: style);
    }
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadsProvider.notifier);

    if (item.isActive) {
      return IconButton(
        icon: const Icon(Icons.stop_circle_outlined),
        tooltip: 'Cancel',
        onPressed: () => notifier.cancel(item.id),
      );
    }

    return IconButton(
      icon: const Icon(Icons.close_rounded),
      tooltip: 'Remove',
      onPressed: () => notifier.remove(item.id),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: item.percent / 100.0,
          borderRadius: BorderRadius.circular(4),
          color: cs.primary,
          backgroundColor: cs.primaryContainer,
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item.percent.toStringAsFixed(1)}%'
              '${item.downloaded.isNotEmpty ? ' · ${item.downloaded}' : ''}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (item.speed.isNotEmpty)
              Text(
                item.speed,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onErrorContainer,
              fontFamily: 'monospace',
            ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.folder_open_rounded, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            filePath,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
