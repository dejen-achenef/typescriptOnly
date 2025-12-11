// features/scan/core/utils/url_utils.dart
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Utility functions for URL validation and launching
class UrlUtils {
  /// Check if a string is a valid URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Normalize URL (add https:// if missing)
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    } else if (trimmed.startsWith('www.')) {
      return 'https://$trimmed';
    } else {
      return 'https://$trimmed';
    }
  }

  /// Launch URL in external browser
  /// 
  /// Returns true if successful, false otherwise
  static Future<bool> launchUrl(String url) async {
    try {
      final normalizedUrl = normalizeUrl(url);
      final uri = Uri.parse(normalizedUrl);
      
      if (!await launcher.canLaunchUrl(uri)) {
        return false;
      }

      return await launcher.launchUrl(
        uri,
        mode: launcher.LaunchMode.externalApplication,
      );
    } catch (e) {
      return false;
    }
  }

  /// Check if URL can be launched
  static Future<bool> canLaunch(String url) async {
    try {
      final normalizedUrl = normalizeUrl(url);
      final uri = Uri.parse(normalizedUrl);
      return await launcher.canLaunchUrl(uri);
    } catch (e) {
      return false;
    }
  }
}

