// features/sync/presentation/screens/conflict_resolution_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Screen for resolving document sync conflicts
class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  final _syncStateService = DocumentSyncStateService.instance;
  List<String> _conflictDocumentIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() {
      _isLoading = true;
    });

    final conflicts = _syncStateService.getDocumentsWithStatus(
      DocumentSyncStatus.conflict,
    );

    setState(() {
      _conflictDocumentIds = conflicts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflicts'),
        backgroundColor: colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conflictDocumentIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conflicts found',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All documents are synced',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conflictDocumentIds.length,
                  itemBuilder: (context, index) {
                    final documentId = _conflictDocumentIds[index];
                    return _ConflictItem(
                      documentId: documentId,
                      onResolved: () {
                        _loadConflicts();
                      },
                    );
                  },
                ),
    );
  }
}

/// Widget for displaying and resolving a single conflict
class _ConflictItem extends StatefulWidget {
  final String documentId;
  final VoidCallback onResolved;

  const _ConflictItem({
    required this.documentId,
    required this.onResolved,
  });

  @override
  State<_ConflictItem> createState() => _ConflictItemState();
}

class _ConflictItemState extends State<_ConflictItem> {
  final _documentService = DocumentService.instance;
  final _syncStateService = DocumentSyncStateService.instance;
  DocumentModel? _localDoc;
  bool _isLoading = true;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final box = await Hive.openBox<DocumentModel>(
        DocumentService.boxName,
      );
      final doc = box.get(widget.documentId);
      setState(() {
        _localDoc = doc;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveConflict(String action) async {
    if (_localDoc == null) return;

    setState(() {
      _isResolving = true;
    });

    try {
      switch (action) {
        case 'keep_local':
          // Keep local version - will be uploaded
          _syncStateService.setSyncStatus(
            widget.documentId,
            DocumentSyncStatus.pendingUpload,
          );
          break;
        case 'use_backend':
          // Use backend version - trigger sync
          await DocumentSyncService.instance.syncDocuments(
            forceFullSync: false,
          );
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conflict resolved: $action'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onResolved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve conflict: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Loading...'),
        ),
      );
    }

    if (_localDoc == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error),
          title: const Text('Document not found'),
          subtitle: Text('ID: ${widget.documentId}'),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localDoc!.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${dateFormat.format(_localDoc!.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Choose how to resolve this conflict:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isResolving
                        ? null
                        : () => _resolveConflict('keep_local'),
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Keep Local'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isResolving
                        ? null
                        : () => _resolveConflict('use_backend'),
                    icon: const Icon(Icons.cloud),
                    label: const Text('Use Backend'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_isResolving)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

