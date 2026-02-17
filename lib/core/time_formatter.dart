import 'package:intl/intl.dart';

/// Utility class for consistent time formatting across the app
class TimeFormatter {
  /// Formats a DateTime to 12-hour format with AM/PM (e.g., "7:30 PM")
  static String format12Hour(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Formats a DateTime to 12-hour format without minutes if on the hour (e.g., "7 PM" or "7:30 PM")
  static String format12HourSmart(DateTime dateTime) {
    if (dateTime.minute == 0) {
      return DateFormat('h a').format(dateTime);
    }
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Formats a DateTime to full date and 12-hour time (e.g., "Feb 5, 2026 at 7:30 PM")
  static String formatFullDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(dateTime);
  }

  /// Formats just the date (e.g., "Feb 5, 2026")
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  /// Formats date with day of week (e.g., "Mon, Feb 5")
  static String formatDateWithDay(DateTime dateTime) {
    return DateFormat('EEE, MMM d').format(dateTime);
  }

  /// Formats time in 12-hour format from hour and minute integers
  static String formatTimeFromInts(int hour, int minute) {
    final dateTime = DateTime(2000, 1, 1, hour, minute);
    return format12Hour(dateTime);
  }
}
