// core/events/document_events.dart
import 'dart:async';

import 'package:thyscan/models/document_model.dart';

/// Base class for document events
abstract class DocumentEvent {
  final String documentId;
  final DateTime timestamp;

  DocumentEvent({
    required this.documentId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Event fired when a document is created
class DocumentCreatedEvent extends DocumentEvent {
  final DocumentModel document;

  DocumentCreatedEvent({
    required super.documentId,
    required this.document,
    super.timestamp,
  });
}

/// Event fired when a document is updated
class DocumentUpdatedEvent extends DocumentEvent {
  final DocumentModel document;
  final DocumentModel? previousDocument;

  DocumentUpdatedEvent({
    required super.documentId,
    required this.document,
    this.previousDocument,
    super.timestamp,
  });
}

/// Event fired when a document is deleted
class DocumentDeletedEvent extends DocumentEvent {
  final bool hardDelete;

  DocumentDeletedEvent({
    required super.documentId,
    this.hardDelete = false,
    super.timestamp,
  });
}

/// Event fired when a document is synced with backend
class DocumentSyncedEvent extends DocumentEvent {
  final bool isUpload;
  final bool success;
  final String? errorMessage;

  DocumentSyncedEvent({
    required super.documentId,
    required this.isUpload,
    required this.success,
    this.errorMessage,
    super.timestamp,
  });
}

/// Event fired when a document sync fails
class DocumentSyncFailedEvent extends DocumentEvent {
  final String error;
  final bool isUpload;
  final int retryCount;

  DocumentSyncFailedEvent({
    required super.documentId,
    required this.error,
    required this.isUpload,
    this.retryCount = 0,
    super.timestamp,
  });
}

/// Event bus for document events
class DocumentEventBus {
  DocumentEventBus._();
  static final DocumentEventBus instance = DocumentEventBus._();

  final _eventController = StreamController<DocumentEvent>.broadcast();

  /// Stream of all document events
  Stream<DocumentEvent> get events => _eventController.stream;

  /// Stream of document created events
  Stream<DocumentCreatedEvent> get createdEvents =>
      events.where((event) => event is DocumentCreatedEvent).cast<DocumentCreatedEvent>();

  /// Stream of document updated events
  Stream<DocumentUpdatedEvent> get updatedEvents =>
      events.where((event) => event is DocumentUpdatedEvent).cast<DocumentUpdatedEvent>();

  /// Stream of document deleted events
  Stream<DocumentDeletedEvent> get deletedEvents =>
      events.where((event) => event is DocumentDeletedEvent).cast<DocumentDeletedEvent>();

  /// Stream of document synced events
  Stream<DocumentSyncedEvent> get syncedEvents =>
      events.where((event) => event is DocumentSyncedEvent).cast<DocumentSyncedEvent>();

  /// Stream of document sync failed events
  Stream<DocumentSyncFailedEvent> get syncFailedEvents =>
      events.where((event) => event is DocumentSyncFailedEvent).cast<DocumentSyncFailedEvent>();

  /// Emits a document event
  void emit(DocumentEvent event) {
    _eventController.add(event);
  }

  /// Emits a document created event
  void emitCreated(DocumentModel document) {
    emit(DocumentCreatedEvent(
      documentId: document.id,
      document: document,
    ));
  }

  /// Emits a document updated event
  void emitUpdated(DocumentModel document, {DocumentModel? previousDocument}) {
    emit(DocumentUpdatedEvent(
      documentId: document.id,
      document: document,
      previousDocument: previousDocument,
    ));
  }

  /// Emits a document deleted event
  void emitDeleted(String documentId, {bool hardDelete = false}) {
    emit(DocumentDeletedEvent(
      documentId: documentId,
      hardDelete: hardDelete,
    ));
  }

  /// Emits a document synced event
  void emitSynced(
    String documentId, {
    required bool isUpload,
    required bool success,
    String? errorMessage,
  }) {
    emit(DocumentSyncedEvent(
      documentId: documentId,
      isUpload: isUpload,
      success: success,
      errorMessage: errorMessage,
    ));
  }

  /// Emits a document sync failed event
  void emitSyncFailed(
    String documentId, {
    required String error,
    required bool isUpload,
    int retryCount = 0,
  }) {
    emit(DocumentSyncFailedEvent(
      documentId: documentId,
      error: error,
      isUpload: isUpload,
      retryCount: retryCount,
    ));
  }

  /// Disposes the event bus
  void dispose() {
    _eventController.close();
  }
}

