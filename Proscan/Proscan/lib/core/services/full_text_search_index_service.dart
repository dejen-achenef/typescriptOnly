// core/services/full_text_search_index_service.dart
import 'dart:async';
import 'dart:collection';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Full-text search index service with inverted index.
/// 
/// Like Microsoft Lens - instant search (<100ms) using pre-built index.
/// 
/// **Features:**
/// - Inverted index: word → document IDs
/// - Extracts text from title, tags, OCR textContent
/// - Persistent storage in Hive
/// - Auto-updates when documents change
/// - Offline-first: works without internet
/// 
/// **Usage:**
/// ```dart
/// // Initialize (call in main.dart)
/// await FullTextSearchIndexService.instance.initialize();
/// 
/// // Search
/// final results = await FullTextSearchIndexService.instance.search('invoice');
/// 
/// // Index is automatically updated when documents change
/// ```
class FullTextSearchIndexService {
  FullTextSearchIndexService._();
  static final FullTextSearchIndexService instance = FullTextSearchIndexService._();

  static const String _indexBoxName = 'full_text_search_index';
  static const String _documentIndexBoxName = 'document_search_index';
  
  Box<Map>? _indexBox; // word → {documentIds: Set<String>, lastUpdated: DateTime}
  Box<Map>? _documentIndexBox; // documentId → {words: Set<String>, lastUpdated: DateTime}
  
  bool _isInitialized = false;
  bool _isIndexing = false;
  Completer<void>? _indexingCompleter;
  
  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Whether indexing is in progress
  bool get isIndexing => _isIndexing;
  
  /// Initializes the search index service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _indexBox = await Hive.openBox<Map>(_indexBoxName);
      _documentIndexBox = await Hive.openBox<Map>(_documentIndexBoxName);
      _isInitialized = true;
      
      AppLogger.info('FullTextSearchIndexService initialized');
      
      // Build index in background if it doesn't exist or is outdated
      _buildIndexInBackground();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize FullTextSearchIndexService',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
  
  /// Builds the full-text search index from all documents
  /// This is called automatically on initialization and when documents change
  Future<void> buildIndex({bool forceRebuild = false}) async {
    if (!_isInitialized || _indexBox == null || _documentIndexBox == null) {
      AppLogger.warning('FullTextSearchIndexService not initialized');
      return;
    }
    
    if (_isIndexing && _indexingCompleter != null) {
      // Wait for existing indexing to complete
      return _indexingCompleter!.future;
    }
    
    _isIndexing = true;
    final newCompleter = Completer<void>();
    _indexingCompleter = newCompleter;
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Get all documents
      final documents = await DocumentRepository.instance.getAllDocuments();
      
      AppLogger.info(
        'Building full-text search index',
        data: {'documentCount': documents.length},
      );
      
      // Clear existing index if force rebuild
      if (forceRebuild) {
        await _indexBox!.clear();
        await _documentIndexBox!.clear();
      }
      
      // Build inverted index: word → Set<documentId>
      final invertedIndex = <String, Set<String>>{};
      final documentWords = <String, Set<String>>{}; // documentId → Set<words>
      
      for (final doc in documents) {
        if (doc.isDeleted) continue;
        
        // Extract searchable text
        final words = _extractWords(doc);
        documentWords[doc.id] = words;
        
        // Add to inverted index
        for (final word in words) {
          invertedIndex.putIfAbsent(word, () => <String>{}).add(doc.id);
        }
      }
      
      // Save to Hive
      await _saveIndex(invertedIndex, documentWords);
      
      stopwatch.stop();
      AppLogger.info(
        'Full-text search index built successfully',
        data: {
          'documentCount': documents.length,
          'uniqueWords': invertedIndex.length,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      
      newCompleter.complete();
      _indexingCompleter = null;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to build search index',
        error: e,
        stack: stack,
      );
      newCompleter.completeError(e);
      _indexingCompleter = null;
    } finally {
      _isIndexing = false;
    }
  }
  
  /// Extracts searchable words from a document
  Set<String> _extractWords(DocumentModel doc) {
    final words = <String>{};
    
    // Extract from title
    words.addAll(_tokenize(doc.title));
    
    // Extract from tags
    for (final tag in doc.tags) {
      words.addAll(_tokenize(tag));
    }
    
    // Extract from textContent (OCR text)
    if (doc.textContent != null && doc.textContent!.isNotEmpty) {
      words.addAll(_tokenize(doc.textContent!));
    }
    
    // Extract from metadata values
    if (doc.metadata != null) {
      for (final value in doc.metadata!.values) {
        if (value is String) {
          words.addAll(_tokenize(value));
        }
      }
    }
    
    return words;
  }
  
  /// Tokenizes text into searchable words
  /// - Converts to lowercase
  /// - Removes punctuation
  /// - Splits on whitespace
  /// - Filters out very short words (< 2 chars) and common stop words
  Set<String> _tokenize(String text) {
    if (text.isEmpty) return {};
    
    // Remove punctuation and convert to lowercase
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
    
    // Split on whitespace
    final words = cleaned.split(RegExp(r'\s+'));
    
    // Filter: min 2 chars, not a stop word
    return words
        .where((word) => word.length >= 2 && !_isStopWord(word))
        .toSet();
  }
  
  /// Common stop words to filter out
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'should', 'could', 'may', 'might', 'must', 'can', 'this',
    'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they',
  };
  
  bool _isStopWord(String word) => _stopWords.contains(word);
  
  /// Saves the index to Hive
  Future<void> _saveIndex(
    Map<String, Set<String>> invertedIndex,
    Map<String, Set<String>> documentWords,
  ) async {
    // Save inverted index: word → documentIds
    for (final entry in invertedIndex.entries) {
      await _indexBox!.put(
        entry.key,
        {
          'documentIds': entry.value.toList(),
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
    }
    
    // Save document index: documentId → words
    for (final entry in documentWords.entries) {
      await _documentIndexBox!.put(
        entry.key,
        {
          'words': entry.value.toList(),
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
    }
  }
  
  /// Searches the index and returns matching document IDs
  /// Returns results in <100ms for typical queries
  Future<List<String>> search(String query, {int maxResults = 1000}) async {
    if (!_isInitialized || _indexBox == null) {
      AppLogger.warning('FullTextSearchIndexService not initialized');
      return [];
    }
    
    if (query.trim().isEmpty) {
      return [];
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Tokenize query
      final queryWords = _tokenize(query);
      if (queryWords.isEmpty) {
        return [];
      }
      
      // Find documents matching ALL words (AND search)
      // For OR search, we could use union instead of intersection
      Set<String>? matchingDocIds;
      
      for (final word in queryWords) {
        final indexData = _indexBox!.get(word) as Map?;
        if (indexData == null) {
          // Word not found in index - no results
          return [];
        }
        
        final docIds = (indexData['documentIds'] as List?)
                ?.map((e) => e as String)
                .toSet() ??
            <String>{};
        
        if (matchingDocIds == null) {
          matchingDocIds = docIds;
        } else {
          // Intersection: documents must contain ALL query words
          matchingDocIds = matchingDocIds!.intersection(docIds);
          if (matchingDocIds.isEmpty) {
            // No documents match all words
            break;
          }
        }
      }
      
      final results = matchingDocIds?.toList() ?? [];
      
      // Limit results
      final limitedResults = results.length > maxResults
          ? results.sublist(0, maxResults)
          : results;
      
      stopwatch.stop();
      
      AppLogger.info(
        'Full-text search completed',
        data: {
          'query': query,
          'queryWords': queryWords.length,
          'resultsCount': limitedResults.length,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );
      
      return limitedResults;
    } catch (e, stack) {
      AppLogger.error(
        'Search failed',
        error: e,
        stack: stack,
        data: {'query': query},
      );
      return [];
    }
  }
  
  /// Updates the index for a single document (called when document is created/updated)
  Future<void> updateDocumentIndex(DocumentModel doc) async {
    if (!_isInitialized || _indexBox == null || _documentIndexBox == null) {
      return;
    }
    
    try {
      // Remove old index entries for this document
      await removeDocumentFromIndex(doc.id);
      
      if (doc.isDeleted) {
        // Document is deleted, already removed from index
        return;
      }
      
      // Extract words from document
      final words = _extractWords(doc);
      
      // Add to inverted index
      for (final word in words) {
        final indexData = _indexBox!.get(word) as Map?;
        final docIds = indexData != null
            ? ((indexData['documentIds'] as List?)?.map((e) => e as String).toSet() ?? <String>{})
            : <String>{};
        
        docIds.add(doc.id);
        
        await _indexBox!.put(
          word,
          {
            'documentIds': docIds.toList(),
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Save document index
      await _documentIndexBox!.put(
        doc.id,
        {
          'words': words.toList(),
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger.info(
        'Document index updated',
        data: {
          'documentId': doc.id,
          'wordCount': words.length,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to update document index',
        error: e,
        stack: stack,
        data: {'documentId': doc.id},
      );
    }
  }
  
  /// Removes a document from the index (called when document is deleted)
  Future<void> removeDocumentFromIndex(String documentId) async {
    if (!_isInitialized || _indexBox == null || _documentIndexBox == null) {
      return;
    }
    
    try {
      // Get words for this document
      final docIndexData = _documentIndexBox!.get(documentId) as Map?;
      if (docIndexData == null) {
        // Document not in index
        return;
      }
      
      final words = (docIndexData['words'] as List?)
              ?.map((e) => e as String)
              .toSet() ??
          <String>{};
      
      // Remove document from inverted index
      for (final word in words) {
        final indexData = _indexBox!.get(word) as Map?;
        if (indexData != null) {
          final docIds = ((indexData['documentIds'] as List?)
                  ?.map((e) => e as String)
                  .toSet() ??
              <String>{});
          
          docIds.remove(documentId);
          
          if (docIds.isEmpty) {
            // No documents left for this word, remove it
            await _indexBox!.delete(word);
          } else {
            await _indexBox!.put(
              word,
              {
                'documentIds': docIds.toList(),
                'lastUpdated': DateTime.now().toIso8601String(),
              },
            );
          }
        }
      }
      
      // Remove document index
      await _documentIndexBox!.delete(documentId);
      
      AppLogger.info(
        'Document removed from index',
        data: {'documentId': documentId},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to remove document from index',
        error: e,
        stack: stack,
        data: {'documentId': documentId},
      );
    }
  }
  
  /// Builds index in background (non-blocking)
  void _buildIndexInBackground() {
    // Check if index exists and is recent
    final hasIndex = _indexBox != null && _indexBox!.isNotEmpty;
    
    if (!hasIndex) {
      // Build index in background
      buildIndex().catchError((error) {
        AppLogger.error(
          'Background index build failed',
          error: error,
        );
      });
    }
  }
  
  /// Gets index statistics
  Map<String, dynamic> getStatistics() {
    if (!_isInitialized || _indexBox == null || _documentIndexBox == null) {
      return {
        'initialized': false,
        'wordCount': 0,
        'documentCount': 0,
      };
    }
    
    return {
      'initialized': true,
      'wordCount': _indexBox!.length,
      'documentCount': _documentIndexBox!.length,
      'isIndexing': _isIndexing,
    };
  }
  
  /// Clears the entire index (use with caution)
  Future<void> clearIndex() async {
    if (!_isInitialized || _indexBox == null || _documentIndexBox == null) {
      return;
    }
    
    await _indexBox!.clear();
    await _documentIndexBox!.clear();
    
    AppLogger.info('Search index cleared');
  }

  /// Clears all search index data
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing FullTextSearchIndexService data');
      await clearIndex();
      AppLogger.info('FullTextSearchIndexService data cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear FullTextSearchIndexService data',
        error: e,
        stack: stack,
      );
    }
  }
}

