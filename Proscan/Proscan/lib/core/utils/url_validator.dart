// core/utils/url_validator.dart
/// Production-ready URL validation and normalization utilities
class UrlValidator {
  /// Validates if a string is a valid HTTP/HTTPS URL
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Normalizes a URL by:
  /// - Trimming whitespace
  /// - Removing trailing slashes
  /// - Ensuring proper format
  static String? normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    var normalized = url.trim();
    
    // Remove trailing slashes
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    
    // Ensure it starts with http:// or https://
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      return null; // Invalid URL format
    }

    return normalized;
  }

  /// Builds a full API endpoint URL from base URL and path
  /// Handles trailing slashes and path joining correctly
  static String? buildApiUrl(String? baseUrl, String path) {
    final normalized = normalizeUrl(baseUrl);
    if (normalized == null) {
      return null;
    }

    // Remove leading slash from path if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    return '$normalized/$cleanPath';
  }
}

