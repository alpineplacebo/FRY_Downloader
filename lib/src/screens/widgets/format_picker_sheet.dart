import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_item.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../rust/api/types.dart';

/// Shows a bottom sheet for picking a format.  Returns after the user taps
/// Download or dismisses.
Future<void> showFormatPicker(
  BuildContext context,
  WidgetRef ref,
  DownloadItem item,
) async {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FormatPickerSheet(item: item),
  );
}

class _FormatPickerSheet extends ConsumerStatefulWidget {
  const _FormatPickerSheet({required this.item});
  final DownloadItem item;

  @override
  ConsumerState<_FormatPickerSheet> createState() => _FormatPickerSheetState();
}

class _FormatPickerSheetState extends ConsumerState<_FormatPickerSheet> {
  late String _outputDir;
  FormatEntry? _selected;

  @override
  void initState() {
    super.initState();
    _outputDir = ref.read(settingsProvider).outputDir;
    final formats = widget.item.mediaInfo?.formats ?? [];
    // Pre-select best combined (non-video-only, non-audio-only) format.
    _selected = formats.where((f) => !f.isVideoOnly && !f.isAudioOnly).lastOrNull ??
        formats.lastOrNull;
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (result != null) setState(() => _outputDir = result);
  }

  void _download() {
    if (_selected == null || _outputDir.isEmpty) return;
    ref.read(downloadsProvider.notifier).startDownload(
          widget.item.id,
          _selected!.formatId,
          _outputDir,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final media = widget.item.mediaInfo!;
    final formats = media.formats;
    final videoFormats = formats.where((f) => !f.isAudioOnly).toList().reversed.toList();
    final audioFormats = formats.where((f) => f.isAudioOnly).toList().reversed.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (media.uploader != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    media.uploader!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                if (media.duration != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(media.duration!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Format list
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (videoFormats.isNotEmpty) ...[
                  _SectionHeader(label: 'Video', icon: Icons.videocam_rounded),
                  ...videoFormats.map((f) => _FormatTile(
                        format: f,
                        selected: _selected?.formatId == f.formatId,
                        onTap: () => setState(() => _selected = f),
                      )),
                ],
                if (audioFormats.isNotEmpty) ...[
                  _SectionHeader(
                      label: 'Audio only', icon: Icons.headphones_rounded),
                  ...audioFormats.map((f) => _FormatTile(
                        format: f,
                        selected: _selected?.formatId == f.formatId,
                        onTap: () => setState(() => _selected = f),
                      )),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Footer: folder + download button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                _FolderSelector(
                  path: _outputDir,
                  onTap: _pickFolder,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_selected != null && _outputDir.isNotEmpty)
                        ? _download
                        : null,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_outputDir.isEmpty
                        ? 'Select a folder first'
                        : 'Download${_selected != null ? ' — ${_selected!.displayName}' : ''}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final FormatEntry format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Radio<bool>(
        value: true,
        groupValue: selected,
        onChanged: (_) => onTap(),
        toggleable: false,
      ),
      title: Text(
        format.displayName,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? cs.primary : null,
        ),
      ),
      onTap: onTap,
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _FolderSelector extends StatelessWidget {
  const _FolderSelector({required this.path, required this.onTap});
  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                path.isEmpty ? 'No folder selected — tap to choose' : path,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: path.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                  fontStyle: path.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
