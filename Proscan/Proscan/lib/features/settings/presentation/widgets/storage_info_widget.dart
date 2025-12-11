import 'package:flutter/material.dart';
import 'package:thyscan/core/services/storage_service.dart';

/// Example widget that displays storage information.
///
/// This demonstrates how to use the StorageService in a Flutter UI.
/// You can integrate this into your settings screen or any other screen.
class StorageInfoWidget extends StatefulWidget {
  const StorageInfoWidget({super.key});

  @override
  State<StorageInfoWidget> createState() => _StorageInfoWidgetState();
}

class _StorageInfoWidgetState extends State<StorageInfoWidget> {
  int? _totalStorage;
  int? _freeStorage;
  int? _usedStorage;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final total = await StorageService.instance.getTotalStorage();
      final free = await StorageService.instance.getFreeStorage();
      final used = await StorageService.instance.getUsedStorage();

      if (mounted) {
        setState(() {
          _totalStorage = total;
          _freeStorage = free;
          _usedStorage = used;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Storage Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStorageInfo,
                  tooltip: 'Refresh storage info',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: TextStyle(color: colorScheme.error),
                ),
              )
            else if (_totalStorage != null &&
                _freeStorage != null &&
                _usedStorage != null)
              Column(
                children: [
                  _buildStorageRow(
                    context,
                    'Total Storage',
                    _formatBytes(_totalStorage!),
                    colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildStorageRow(
                    context,
                    'Used Storage',
                    _formatBytes(_usedStorage!),
                    colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  _buildStorageRow(
                    context,
                    'Free Storage',
                    _formatBytes(_freeStorage!),
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  // Progress bar showing usage
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _totalStorage! > 0
                          ? _usedStorage! / _totalStorage!
                          : 0,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${((_usedStorage! / _totalStorage!) * 100).toStringAsFixed(1)}% used',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

