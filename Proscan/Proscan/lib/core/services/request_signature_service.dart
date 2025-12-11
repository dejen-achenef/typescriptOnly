// core/services/request_signature_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';

/// Service for generating HMAC request signatures for critical operations.
/// 
/// Provides request signing to prevent tampering and replay attacks.
/// 
/// **Usage:**
/// ```dart
/// final signature = RequestSignatureService.instance.generateSignature(
///   method: 'PUT',
///   path: '/api/documents/123',
///   body: {'title': 'Updated Title'},
/// );
/// 
/// // Include in headers:
/// headers['X-Request-Signature'] = signature.signature;
/// headers['X-Request-Timestamp'] = signature.timestamp.toString();
/// ```
class RequestSignatureService {
  RequestSignatureService._();
  static final RequestSignatureService instance = RequestSignatureService._();

  /// Generates HMAC signature for a request
  /// 
  /// **Parameters:**
  /// - `method`: HTTP method (GET, POST, PUT, DELETE, etc.)
  /// - `path`: Request path (e.g., '/api/documents/123')
  /// - `body`: Request body (will be JSON-encoded if not null)
  /// 
  /// **Returns:**
  /// - `RequestSignature` containing signature and timestamp
  /// 
  /// **Throws:**
  /// - `Exception` if secret is not configured or user is not authenticated
  RequestSignature generateSignature({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    final secret = AppEnv.requestSignatureSecret;
    
    if (secret == null || secret.isEmpty) {
      // In development, allow requests without signature if secret is not configured
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        AppLogger.warning(
          'REQUEST_SIGNATURE_SECRET not configured, skipping signature generation',
          error: null,
        );
        return RequestSignature(
          signature: '',
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }
      throw Exception('REQUEST_SIGNATURE_SECRET not configured');
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to generate request signature');
    }

    // Get current timestamp (Unix timestamp in seconds)
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Normalize path (remove query string for signature)
    final normalizedPath = path.split('?')[0];

    // Serialize body consistently (sorted keys)
    String bodyString = '';
    if (body != null) {
      // Convert body to a sorted map for consistent serialization
      if (body is Map<String, dynamic>) {
        final sortedKeys = body.keys.toList()..sort();
        final sortedBody = <String, dynamic>{};
        for (final key in sortedKeys) {
          sortedBody[key] = body[key];
        }
        bodyString = jsonEncode(sortedBody);
      } else {
        bodyString = jsonEncode(body);
      }
    }

    // Create message: method + path + body + timestamp + userId
    final message = '${method.toUpperCase()}\n$normalizedPath\n$bodyString\n$timestamp\n${user.id}';

    // Compute HMAC-SHA256
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    final signature = digest.toString();

    AppLogger.info(
      'Generated request signature',
      data: {
        'method': method,
        'path': normalizedPath,
        'timestamp': timestamp,
        'userId': user.id,
      },
    );

    return RequestSignature(
      signature: signature,
      timestamp: timestamp,
    );
  }
}

/// Request signature data
class RequestSignature {
  final String signature;
  final int timestamp;

  RequestSignature({
    required this.signature,
    required this.timestamp,
  });
}

