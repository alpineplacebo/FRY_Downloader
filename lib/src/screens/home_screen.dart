import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import 'settings_screen.dart';
import 'widgets/download_item_card.dart';
import 'widgets/url_input_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final active = downloads.where((d) => !d.isDone).toList();
    final done = downloads.where((d) => d.isDone).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.cloud_download_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Text('FRY Downloader'),
          ],
        ),
        actions: [
          if (done.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).clearCompleted(),
              icon: const Icon(Icons.playlist_remove_rounded, size: 18),
              label: const Text('Clear done'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: downloads.isEmpty
          ? const _EmptyState()
          : _DownloadList(active: active, done: done),
      // URL input is always pinned at the top.
      // We use a Column-based layout so the input card floats above the list.
      // The input card is rendered as a persistent header via a CustomScrollView.
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        const UrlInputCard(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_for_offline_rounded,
                  size: 80,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing to download yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste a URL above to get started.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadList extends StatelessWidget {
  const _DownloadList({required this.active, required this.done});
  final List<DownloadItem> active;
  final List<DownloadItem> done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: const UrlInputCard()),
        if (active.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.pending_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'In Progress (${active.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => DownloadItemCard(item: active[i]),
              childCount: active.length,
            ),
          ),
        ],
        if (done.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'History',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => DownloadItemCard(item: done[i]),
              childCount: done.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
