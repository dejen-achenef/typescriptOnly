// core/utils/greeting_utils.dart
import 'dart:async';

/// Utility class for generating time-based greetings (like CamScanner/Genius Scan).
/// Handles all timezone logic and provides reactive greeting updates.
class GreetingUtils {
  GreetingUtils._();

  /// Gets the appropriate greeting based on current time in local timezone.
  /// 
  /// Time ranges:
  /// - 5:00 – 11:59 → "Good morning"
  /// - 12:00 – 16:59 → "Good afternoon"
  /// - 17:00 – 20:59 → "Good evening"
  /// - 21:00 – 4:59 → "Good night"
  static String getGreeting({DateTime? time}) {
    final now = time ?? DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      // 21:00 – 4:59
      return 'Good night';
    }
  }

  /// Gets the full greeting with user's name if provided.
  /// Returns just the greeting if name is null or empty.
  static String getFullGreeting({String? userName, DateTime? time}) {
    final greeting = getGreeting(time: time);
    if (userName != null && userName.isNotEmpty) {
      return '$greeting, $userName';
    }
    return greeting;
  }

  /// Creates a stream that emits the current greeting and updates when time
  /// crosses greeting boundaries (5:00, 12:00, 17:00, 21:00).
  /// 
  /// Updates every minute to catch boundary crossings.
  static Stream<String> greetingStream({String? userName}) {
    return Stream.periodic(
      const Duration(minutes: 1),
      (_) => getFullGreeting(userName: userName),
    ).distinct(); // Only emit when greeting actually changes
  }

  /// Calculates the next time when the greeting will change.
  /// Used for optimizing stream updates.
  static DateTime getNextGreetingChangeTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    DateTime nextChange;
    if (hour < 5) {
      // Next change is at 5:00 today
      nextChange = DateTime(now.year, now.month, now.day, 5, 0);
    } else if (hour < 12) {
      // Next change is at 12:00 today
      nextChange = DateTime(now.year, now.month, now.day, 12, 0);
    } else if (hour < 17) {
      // Next change is at 17:00 today
      nextChange = DateTime(now.year, now.month, now.day, 17, 0);
    } else if (hour < 21) {
      // Next change is at 21:00 today
      nextChange = DateTime(now.year, now.month, now.day, 21, 0);
    } else {
      // Next change is at 5:00 tomorrow
      final tomorrow = now.add(const Duration(days: 1));
      nextChange = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 5, 0);
    }

    return nextChange;
  }
}

