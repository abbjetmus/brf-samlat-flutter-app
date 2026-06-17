import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AppDateUtils {
  static Future<void> initializeLocale() async {
    await initializeDateFormatting('sv_SE', null);
  }

  /// Format: "2024-01-15 14:30"
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm', 'sv_SE').format(date);
  }

  /// Format: "2024-01-15"
  static String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd', 'sv_SE').format(date);
  }

  /// Format: "15 januari 2024"
  static String formatDateLong(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('d MMMM yyyy', 'sv_SE').format(date);
  }

  /// Format: "14:30"
  static String formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('HH:mm', 'sv_SE').format(date);
  }

  /// Format: "januari"
  static String formatMonth(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('MMMM', 'sv_SE').format(date);
  }

  /// Format: "15 jan"
  static String formatDayAndMonth(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('d MMM', 'sv_SE').format(date);
  }

  /// Format: "Mån 15 jan 2024"
  static String formatDateCalendar(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    return DateFormat('E d MMM yyyy', 'sv_SE').format(date);
  }

  /// Swedish relative time (e.g. "just nu", "5 min sedan", "1 dag sedan")
  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'just nu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min sedan';
    if (diff.inHours < 24) return '${diff.inHours} tim sedan';
    if (diff.inDays < 7) return '${diff.inDays} dag${diff.inDays > 1 ? 'ar' : ''} sedan';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks veck${weeks > 1 ? 'or' : 'a'} sedan';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months månad${months > 1 ? 'er' : ''} sedan';
    }
    final years = (diff.inDays / 365).floor();
    return '$years år sedan';
  }

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
