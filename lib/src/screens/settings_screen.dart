import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../rust/api/downloader.dart' as bridge;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _ytdlpController;
  String? _ytdlpVersion;
  bool _checkingVersion = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _ytdlpController = TextEditingController(text: settings.ytdlpPath);
    _checkVersion();
  }

  @override
  void dispose() {
    _ytdlpController.dispose();
    super.dispose();
  }

  Future<void> _checkVersion() async {
    setState(() {
      _checkingVersion = true;
      _ytdlpVersion = null;
    });
    try {
      final path = _ytdlpController.text.trim();
      final version = await bridge.getYtdlpVersion(ytdlpPath: path);
      if (mounted) setState(() => _ytdlpVersion = version);
    } catch (e) {
      if (mounted) setState(() => _ytdlpVersion = 'Not found');
    } finally {
      if (mounted) setState(() => _checkingVersion = false);
    }
  }

  Future<void> _pickYtdlpFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Locate yt-dlp',
      type: FileType.custom,
      allowedExtensions: ['exe', '*'],
    );
    if (result?.files.single.path != null) {
      _ytdlpController.text = result!.files.single.path!;
      await ref
          .read(settingsProvider.notifier)
          .setYtdlpPath(_ytdlpController.text.trim());
      _checkVersion();
    }
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Default download folder',
    );
    if (result != null) {
      await ref.read(settingsProvider.notifier).setOutputDir(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ---- yt-dlp ----
          _SectionTitle(icon: Icons.terminal_rounded, label: 'yt-dlp'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ytdlpController,
                    decoration: InputDecoration(
                      labelText: 'yt-dlp path',
                      hintText: 'yt-dlp',
                      border: const OutlineInputBorder(),
                      suffixIcon: _checkingVersion
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Check version',
                              onPressed: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setYtdlpPath(
                                        _ytdlpController.text.trim());
                                _checkVersion();
                              },
                            ),
                    ),
                    onSubmitted: (v) {
                      ref
                          .read(settingsProvider.notifier)
                          .setYtdlpPath(v.trim());
                      _checkVersion();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.folder_rounded),
                  tooltip: 'Browse…',
                  onPressed: _pickYtdlpFile,
                ),
              ],
            ),
          ),
          if (_ytdlpVersion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(
                    _ytdlpVersion == 'Not found'
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: _ytdlpVersion == 'Not found'
                        ? cs.error
                        : cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ytdlpVersion == 'Not found'
                        ? 'yt-dlp not found at that path'
                        : 'yt-dlp $_ytdlpVersion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _ytdlpVersion == 'Not found'
                          ? cs.error
                          : cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Enter "yt-dlp" to use the system PATH, or browse to the '
              'yt-dlp / yt-dlp.exe binary.',
              style: TextStyle(fontSize: 12),
            ),
          ),

          // ---- Output directory ----
          _SectionTitle(icon: Icons.folder_rounded, label: 'Downloads folder'),
          ListTile(
            leading: Icon(Icons.folder_open_rounded, color: cs.primary),
            title: const Text('Default download folder'),
            subtitle: Text(
              settings.outputDir.isEmpty
                  ? 'Not set — you will be asked each time'
                  : settings.outputDir,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickOutputDir,
          ),
          const Divider(indent: 16, endIndent: 16),

          // ---- Concurrent downloads ----
          _SectionTitle(
              icon: Icons.tune_rounded, label: 'Download behaviour'),
          ListTile(
            leading: Icon(Icons.queue_rounded, color: cs.primary),
            title: const Text('Max concurrent downloads'),
            subtitle: Text('${settings.maxConcurrent}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: settings.maxConcurrent > 1
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setMaxConcurrent(settings.maxConcurrent - 1)
                      : null,
                ),
                Text(
                  '${settings.maxConcurrent}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: settings.maxConcurrent < 5
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setMaxConcurrent(settings.maxConcurrent + 1)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ---- Theme ----
          _SectionTitle(icon: Icons.palette_rounded, label: 'Appearance'),
          ...ThemeMode.values.map((mode) {
            final labels = {
              ThemeMode.system: 'System default',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            };
            final icons = {
              ThemeMode.system: Icons.brightness_auto_rounded,
              ThemeMode.light: Icons.light_mode_rounded,
              ThemeMode.dark: Icons.dark_mode_rounded,
            };
            return RadioListTile<ThemeMode>(
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setThemeMode(v!),
              title: Text(labels[mode]!),
              secondary: Icon(icons[mode]!),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
