// core/services/rate_limiter_service.dart
import 'dart:async';

import 'package:thyscan/core/services/app_logger.dart';

/// Rate limiter using token bucket algorithm
/// 
/// Prevents excessive API calls and operations by limiting the rate
/// at which operations can be performed.
class RateLimiterService {
  RateLimiterService._();
  static final RateLimiterService instance = RateLimiterService._();

  // Token buckets for different operation types
  final Map<String, _TokenBucket> _buckets = {};

  /// Rate limit configuration
  static const Map<String, _RateLimitConfig> _rateLimits = {
    'document_upload': _RateLimitConfig(
      maxTokens: 10,
      refillRate: 10, // tokens per minute
    ),
    'document_sync': _RateLimitConfig(
      maxTokens: 5,
      refillRate: 5, // tokens per minute
    ),
    'api_call': _RateLimitConfig(
      maxTokens: 30,
      refillRate: 30, // tokens per minute
    ),
  };

  /// Checks if an operation is allowed and consumes a token if available
  /// 
  /// Returns true if operation is allowed, false if rate limited
  bool tryAcquire(String operationType) {
    final bucket = _getOrCreateBucket(operationType);
    return bucket.tryConsume();
  }

  /// Waits until a token is available, then consumes it
  /// 
  /// Returns a future that completes when the operation is allowed
  Future<void> acquire(String operationType) async {
    final bucket = _getOrCreateBucket(operationType);
    
    while (!bucket.tryConsume()) {
      // Calculate wait time until next token is available
      final waitTime = bucket.timeUntilNextToken();
      if (waitTime > Duration.zero) {
        AppLogger.info(
          'Rate limited, waiting ${waitTime.inSeconds}s',
          data: {'operationType': operationType},
        );
        await Future.delayed(waitTime);
      } else {
        // Small delay to prevent tight loop
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Gets the number of available tokens for an operation type
  int getAvailableTokens(String operationType) {
    final bucket = _buckets[operationType];
    if (bucket == null) {
      final config = _rateLimits[operationType];
      return config?.maxTokens ?? 0;
    }
    return bucket.availableTokens;
  }

  /// Gets the time until the next token is available
  Duration getTimeUntilNextToken(String operationType) {
    final bucket = _buckets[operationType];
    if (bucket == null) return Duration.zero;
    return bucket.timeUntilNextToken();
  }

  /// Resets the rate limiter for an operation type
  void reset(String operationType) {
    _buckets.remove(operationType);
  }

  /// Resets all rate limiters
  void resetAll() {
    _buckets.clear();
  }

  _TokenBucket _getOrCreateBucket(String operationType) {
    return _buckets.putIfAbsent(
      operationType,
      () {
        final config = _rateLimits[operationType] ?? _RateLimitConfig(
          maxTokens: 10,
          refillRate: 10,
        );
        return _TokenBucket(
          maxTokens: config.maxTokens,
          refillRate: config.refillRate,
        );
      },
    );
  }
}

/// Rate limit configuration
class _RateLimitConfig {
  final int maxTokens;
  final int refillRate; // tokens per minute

  const _RateLimitConfig({
    required this.maxTokens,
    required this.refillRate,
  });
}

/// Token bucket implementation
class _TokenBucket {
  final int maxTokens;
  final int refillRate; // tokens per minute
  int _tokens;
  DateTime _lastRefill;

  _TokenBucket({
    required this.maxTokens,
    required this.refillRate,
  })  : _tokens = maxTokens,
        _lastRefill = DateTime.now();

  /// Tries to consume a token
  /// Returns true if token was consumed, false if bucket is empty
  bool tryConsume() {
    _refill();
    if (_tokens > 0) {
      _tokens--;
      return true;
    }
    return false;
  }

  /// Gets the number of available tokens
  int get availableTokens {
    _refill();
    return _tokens;
  }

  /// Gets the time until the next token is available
  Duration timeUntilNextToken() {
    _refill();
    if (_tokens > 0) return Duration.zero;

    // Calculate time until next token
    final tokensNeeded = 1;
    final tokensPerSecond = refillRate / 60.0;
    final secondsNeeded = tokensNeeded / tokensPerSecond;
    return Duration(milliseconds: (secondsNeeded * 1000).round());
  }

  /// Refills tokens based on elapsed time
  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);
    
    if (elapsed.inSeconds >= 60) {
      // Refill based on refill rate
      final tokensToAdd = (refillRate * elapsed.inMinutes).round();
      _tokens = (_tokens + tokensToAdd).clamp(0, maxTokens);
      _lastRefill = now;
    } else {
      // Calculate partial refill for sub-minute intervals
      final tokensPerSecond = refillRate / 60.0;
      final tokensToAdd = (tokensPerSecond * elapsed.inSeconds).round();
      if (tokensToAdd > 0) {
        _tokens = (_tokens + tokensToAdd).clamp(0, maxTokens);
        _lastRefill = now;
      }
    }
  }
}

