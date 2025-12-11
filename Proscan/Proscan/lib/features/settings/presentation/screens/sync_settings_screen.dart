// features/settings/presentation/screens/sync_settings_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';

/// Screen for configuring document sync settings
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  static const String _settingsBoxName = 'sync_settings';
  Box<dynamic>? _settingsBox;

  bool _autoSyncEnabled = true;
  bool _wifiOnlySync = false;
  bool _backgroundSync = true;
  String _syncFrequency = 'auto'; // auto, hourly, daily, manual
  bool _isLoading = true;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Listen to sync status changes for real-time updates
    _statusSubscription = DocumentSyncStateService.instance.statusStream.listen(
      (_) {
        if (mounted) {
          setState(() {}); // Refresh UI when sync status changes
        }
      },
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    // Settings box is managed by Hive, no need to close it here
    // Hive will handle cleanup automatically
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      _settingsBox = await Hive.openBox(_settingsBoxName);

      if (mounted) {
        setState(() {
          _autoSyncEnabled =
              _settingsBox?.get('autoSyncEnabled', defaultValue: true)
                  as bool? ??
              true;
          _wifiOnlySync =
              _settingsBox?.get('wifiOnlySync', defaultValue: false) as bool? ??
              false;
          _backgroundSync =
              _settingsBox?.get('backgroundSync', defaultValue: true)
                  as bool? ??
              true;
          _syncFrequency =
              _settingsBox?.get('syncFrequency', defaultValue: 'auto')
                  as String? ??
              'auto';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      AppLogger.error('Failed to load sync settings', error: e, stack: stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      if (_settingsBox != null) {
        await _settingsBox!.put(key, value);
        AppLogger.info(
          'Sync setting saved',
          data: {'key': key, 'value': value},
        );
      } else {
        AppLogger.warning(
          'Settings box not initialized, cannot save setting',
          error: null,
          data: {'key': key, 'value': value},
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to save sync setting',
        error: e,
        stack: stack,
        data: {'key': key, 'value': value},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sync Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final stats = DocumentSyncStateService.instance.getStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        backgroundColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sync Statistics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Synced',
                        value: stats.synced.toString(),
                        color: Colors.green,
                      ),
                      _StatItem(
                        label: 'Pending',
                        value: (stats.pendingUpload + stats.pendingDownload)
                            .toString(),
                        color: Colors.orange,
                      ),
                      _StatItem(
                        label: 'Issues',
                        value: (stats.conflict + stats.error).toString(),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: stats.syncPercentage / 100,
                    backgroundColor: colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${stats.syncPercentage.toStringAsFixed(1)}% synced',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (DocumentSyncService.instance.isSyncing)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Syncing...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (stats.total > 0) ...[
                    const SizedBox(height: 12),
                    // Detailed breakdown
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (stats.pendingUpload > 0)
                          _StatusChip(
                            label: '${stats.pendingUpload} pending upload',
                            color: Colors.orange,
                          ),
                        if (stats.pendingDownload > 0)
                          _StatusChip(
                            label: '${stats.pendingDownload} pending download',
                            color: Colors.blue,
                          ),
                        if (stats.conflict > 0)
                          _StatusChip(
                            label: '${stats.conflict} conflict(s)',
                            color: Colors.red,
                          ),
                        if (stats.error > 0)
                          _StatusChip(
                            label: '${stats.error} error(s)',
                            color: Colors.red,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Auto Sync Toggle
          Card(
            child: SwitchListTile(
              title: const Text('Auto Sync'),
              subtitle: const Text('Automatically sync documents when online'),
              value: _autoSyncEnabled,
              onChanged: (value) {
                setState(() {
                  _autoSyncEnabled = value;
                });
                _saveSetting('autoSyncEnabled', value);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Wi-Fi Only Sync
          Card(
            child: Opacity(
              opacity: _autoSyncEnabled ? 1.0 : 0.5,
              child: SwitchListTile(
                title: const Text('Wi-Fi Only'),
                subtitle: const Text('Only sync when connected to Wi-Fi'),
                value: _wifiOnlySync,
                onChanged: _autoSyncEnabled
                    ? (value) {
                        setState(() {
                          _wifiOnlySync = value;
                        });
                        _saveSetting('wifiOnlySync', value);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Background Sync
          Card(
            child: Opacity(
              opacity: _autoSyncEnabled ? 1.0 : 0.5,
              child: SwitchListTile(
                title: const Text('Background Sync'),
                subtitle: const Text('Sync documents in the background'),
                value: _backgroundSync,
                onChanged: _autoSyncEnabled
                    ? (value) {
                        setState(() {
                          _backgroundSync = value;
                        });
                        _saveSetting('backgroundSync', value);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sync Frequency
          Card(
            child: ListTile(
              title: const Text('Sync Frequency'),
              subtitle: Text(_getSyncFrequencyDescription(_syncFrequency)),
              trailing: DropdownButton<String>(
                value: _syncFrequency,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                  DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                ],
                onChanged: _autoSyncEnabled
                    ? (value) {
                        if (value != null) {
                          setState(() {
                            _syncFrequency = value;
                          });
                          _saveSetting('syncFrequency', value);
                        }
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Manual Sync Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Now'),
              subtitle: const Text('Manually trigger document sync'),
              onTap: () async {
                try {
                  // Show loading indicator
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Syncing documents...'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }

                  // Trigger manual sync
                  final result = await DocumentSyncService.instance
                      .syncDocuments(
                        forceFullSync: false, // Use incremental sync
                        replaceLocal: false, // Safe merge mode
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.success
                              ? 'Sync completed: ${result.documentsAdded} added, ${result.documentsUpdated} updated'
                              : 'Sync failed: ${result.message}',
                        ),
                        backgroundColor: result.success
                            ? Colors.green
                            : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }

                  // Refresh statistics
                  if (context.mounted) {
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sync error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // View Conflicts Button
          if (stats.conflict > 0)
            Card(
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text('Resolve Conflicts (${stats.conflict})'),
                subtitle: const Text('View and resolve sync conflicts'),
                onTap: () {
                  try {
                    context.push('/conflict-resolution');
                  } catch (e) {
                    // If route doesn't exist, show message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Conflict resolution: ${stats.conflict} conflict(s) detected. Please check your documents.',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  String _getSyncFrequencyDescription(String frequency) {
    switch (frequency) {
      case 'auto':
        return 'Sync automatically when changes are detected';
      case 'hourly':
        return 'Sync every hour';
      case 'daily':
        return 'Sync once per day';
      case 'manual':
        return 'Sync only when manually triggered';
      default:
        return 'Unknown';
    }
  }
}

/// Widget for displaying a sync statistic
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Widget for displaying sync status chips
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
