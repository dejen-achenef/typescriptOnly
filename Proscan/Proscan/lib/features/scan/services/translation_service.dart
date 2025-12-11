import 'dart:async';
import 'dart:io';

import 'package:translator/translator.dart';

/// Unified failure type for all translation-related errors.
class TranslationFailure implements Exception {
  TranslationFailure(this.message, {this.cause, this.statusCode});

  final String message;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() {
    final base = 'TranslationFailure: $message';
    if (statusCode != null && cause != null) {
      return '$base (statusCode: $statusCode, cause: $cause)';
    }
    if (statusCode != null) {
      return '$base (statusCode: $statusCode)';
    }
    if (cause != null) {
      return '$base (cause: $cause)';
    }
    return base;
  }
}

/// Robust translation service built on top of the `translator` package.
///
/// Responsibilities:
/// - Basic offline check before calling the network API
/// - In‑memory caching using a composite key: `$from-$to-$originalTextHash`
/// - Retry with exponential backoff (0.8s → 1.6s → 3.2s)
/// - Simple rate‑limit protection: at least 300ms between calls
class TranslationService {
  TranslationService({GoogleTranslator? translator})
      : _translator = translator ?? GoogleTranslator();

  final GoogleTranslator _translator;

  // In‑memory cache: key -> translated text
  final Map<String, String> _cache = <String, String>{};

  // Timestamp of the last outbound translation request (for rate limiting)
  DateTime? _lastRequestAt;

  /// Main entry point used by the rest of the app.
  ///
  /// Throws [TranslationFailure] for all error conditions.
  Future<String> translateSafe({
    required String text,
    String from = 'auto',
    required String to,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw TranslationFailure('Text to translate must not be empty.');
    }

    final cacheKey = _buildCacheKey(from: from, to: to, text: trimmed);

    // 1. Check cache first
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    // 2. Offline check before attempting any network work
    final online = await _hasNetworkConnectivity();
    if (!online) {
      throw TranslationFailure('No internet connection detected.');
    }

    // 3. Basic rate‑limit protection (300ms between calls)
    await _enforceRateLimitCooldown();

    const maxAttempts = 3;
    const baseDelayMs = 800; // 0.8s base for exponential backoff

    Object? lastError;
    int? lastStatusCode;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        _lastRequestAt = DateTime.now();
        final result = await _translator.translate(trimmed, from: from, to: to);
        final translated = result.text;

        _cache[cacheKey] = translated;
        return translated;
      } catch (e) {
        lastError = e;
        // `translator` does not expose HTTP status codes directly; keep null.

        // If this was not the last attempt, back off and try again.
        if (attempt < maxAttempts - 1) {
          final delayMs = baseDelayMs * (1 << attempt); // 0.8s, 1.6s, 3.2s
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    throw TranslationFailure(
      'Translation failed. Please try again later.',
      cause: lastError,
      statusCode: lastStatusCode,
    );
  }

  String _buildCacheKey({required String from, required String to, required String text}) {
    final hash = text.hashCode;
    return '$from-$to-$hash';
  }

  Future<void> _enforceRateLimitCooldown() async {
    const minGapMs = 300;
    final last = _lastRequestAt;
    if (last == null) return;

    final elapsedMs = DateTime.now().difference(last).inMilliseconds;
    if (elapsedMs < minGapMs) {
      await Future.delayed(Duration(milliseconds: minGapMs - elapsedMs));
    }
  }

  Future<bool> _hasNetworkConnectivity() async {
    try {
      // Lightweight DNS lookup as a proxy for connectivity.
      final result = await InternetAddress.lookup('translate.googleapis.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
