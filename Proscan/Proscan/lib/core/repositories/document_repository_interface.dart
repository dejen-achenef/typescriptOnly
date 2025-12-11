// core/repositories/document_repository_interface.dart
import 'package:thyscan/models/document_model.dart';

/// Abstract interface for document repository
/// 
/// Defines the contract for document data access operations.
/// Implementations can use Hive (local), backend API, or both.
abstract class IDocumentRepository {
  /// Get document by ID
  Future<DocumentModel?> getDocumentById(String id);

  /// Get all documents
  Future<List<DocumentModel>> getAllDocuments({bool includeDeleted = false});

  /// Get documents by IDs
  Future<List<DocumentModel>> getDocumentsByIds(List<String> ids);

  /// Get document count
  Future<int> getDocumentCount({bool includeDeleted = false});

  /// Save document
  Future<void> saveDocument(DocumentModel doc);

  /// Update document
  Future<void> updateDocument(DocumentModel doc);

  /// Delete document
  Future<void> deleteDocument(String id);

  /// Clear cache
  void clearCache();

  /// Invalidate cache for a specific document
  void invalidateDocument(String id);
}

