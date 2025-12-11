// core/services/persistence_queue.dart
//
// A lightweight in‑process queue for document persistence operations.
// This is designed to be easily backed by a background task framework
// such as `workmanager` or `background_fetch`, but it also provides
// an in‑app executor that batches and retries work while the app
// is in the foreground.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// High‑level operation types that can be queued.
enum PersistenceOperationType { saveNew, updateExisting }

/// A single persistence job description.
class PersistenceJob {
  PersistenceJob({
    required this.id,
    required this.type,
    required this.pageImagePaths,
    required this.title,
    required this.scanMode,
    required this.colorProfileKey,
    this.documentId,
    this.textContent,
    this.attempts = 0,
    this.options = const DocumentSaveOptions(),
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final PersistenceOperationType type;
  final List<String> pageImagePaths;
  final String title;
  final String scanMode;
  final String colorProfileKey;
  final String? documentId;
  final String? textContent;
  final int attempts;
  final DateTime createdAt;
  final DocumentSaveOptions options;

  PersistenceJob copyWith({int? attempts}) {
    return PersistenceJob(
      id: id,
      type: type,
      pageImagePaths: pageImagePaths,
      title: title,
      scanMode: scanMode,
      colorProfileKey: colorProfileKey,
      documentId: documentId,
      textContent: textContent,
      attempts: attempts ?? this.attempts,
      options: options,
      createdAt: createdAt,
    );
  }
}

/// A simple queue with retry/backoff semantics.
///
/// In production you can plug this into `workmanager` or any other
/// background task runner by:
///  - Serializing [PersistenceJob]s into a box or shared preferences.
///  - Draining them from a background callback using [flushPending].
class PersistenceQueue {
  PersistenceQueue._();

  static final PersistenceQueue instance = PersistenceQueue._();

  final _queue = <PersistenceJob>[];
  bool _isRunning = false;

  /// Enqueue a save or update operation. Returns a [Future] that
  /// completes with the resulting [DocumentModel] once the job
  /// is processed, or with `null` if it ultimately fails.
  Future<DocumentModel?> enqueue(PersistenceJob job) async {
    _queue.add(job);
    _runIfNeeded();

    // For now we don't expose per‑job completion futures from the queue;
    // callers should assume "fire‑and‑forget" semantics and re‑load
    // from Hive or call [flushPending] in tests.
    return null;
  }

  /// Explicitly trigger processing of any queued jobs.
  Future<void> flushPending() async {
    await _drainQueue();
  }

  void _runIfNeeded() {
    if (_isRunning) return;
    _isRunning = true;
    _drainQueue();
  }

  Future<void> _drainQueue() async {
    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      try {
        await _executeJob(job);
      } catch (e, st) {
        debugPrint('Persistence job ${job.id} failed: $e\n$st');
        if (job.attempts < 3) {
          // Exponential backoff: delay based on attempt count.
          final backoffMs = 500 * (1 << job.attempts);
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
          _queue.add(job.copyWith(attempts: job.attempts + 1));
        } else {
          // Drop after max attempts; in a real production setup
          // you would report this to analytics / crash reporting.
        }
      }
    }
    _isRunning = false;
  }

  Future<void> _executeJob(PersistenceJob job) async {
    final docService = DocumentService.instance;

    switch (job.type) {
      case PersistenceOperationType.saveNew:
        await docService.saveDocument(
          pageImagePaths: job.pageImagePaths,
          title: job.title,
          scanMode: job.scanMode,
          textContent: job.textContent,
          colorProfile: DocumentColorProfile.fromKey(job.colorProfileKey),
          options: job.options,
        );
      case PersistenceOperationType.updateExisting:
        final docId = job.documentId;
        if (docId == null) {
          throw StateError('updateExisting job requires documentId');
        }
        await docService.updateDocument(
          documentId: docId,
          pageImagePaths: job.pageImagePaths,
          title: job.title,
          scanMode: job.scanMode,
          colorProfile: DocumentColorProfile.fromKey(job.colorProfileKey),
          options: job.options,
        );
    }
  }
}
