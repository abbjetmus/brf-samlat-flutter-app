import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AppDateUtils {
  static Future<void> initializeLocale() async {
    await initializeDateFormatting('sv_SE', null);
  }

  /// Format: "2024-01-15 14:30"
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm', 'sv_SE').format(date);
  }

  /// Format: "2024-01-15"
  static String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd', 'sv_SE').format(date);
  }

  /// Format: "15 januari 2024"
  static String formatDateLong(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('d MMMM yyyy', 'sv_SE').format(date);
  }

  /// Format: "14:30"
  static String formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('HH:mm', 'sv_SE').format(date);
  }

  /// Format: "januari"
  static String formatMonth(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('MMMM', 'sv_SE').format(date);
  }

  /// Format: "15 jan"
  static String formatDayAndMonth(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('d MMM', 'sv_SE').format(date);
  }

  /// Format: "Mån 15 jan 2024"
  static String formatDateCalendar(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('E d MMM yyyy', 'sv_SE').format(date);
  }

  /// Swedish relative time (e.g. "just nu", "5 min sedan", "1 dag sedan")
  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
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

  /// "Idag", "Igår", "14 nov" (with the year when it isn't this year).
  static String friendlyDay(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Idag';
    if (diff == 1) return 'Igår';
    return DateFormat(
      date.year == now.year ? 'd MMM' : 'd MMM yyyy',
      'sv_SE',
    ).format(date);
  }

  /// "Torsdag 20 november" for today (or [date]).
  static String weekdayLong([DateTime? date]) {
    final text = DateFormat('EEEE d MMMM', 'sv_SE').format(
      date ?? DateTime.now(),
    );
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  /// Short upper-case month for date blocks: "NOV".
  static String monthShortUpper(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return DateFormat('MMM', 'sv_SE').format(date).replaceAll('.', '').toUpperCase();
  }

  /// Day of month: "27".
  static String dayOfMonth(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';
    return '${date.day}';
  }

  /// "Lördag 10:00–13:00" / "Lördag 22 nov 10:00" for an event.
  static String eventWhen(String? startIso, String? endIso) {
    final start = DateTime.tryParse(startIso ?? '')?.toLocal();
    if (start == null) return '';
    final end = DateTime.tryParse(endIso ?? '')?.toLocal();
    final wd = DateFormat('EEEE', 'sv_SE').format(start);
    final weekday = wd.isEmpty ? wd : wd[0].toUpperCase() + wd.substring(1);
    final from = DateFormat('HH:mm', 'sv_SE').format(start);
    if (end == null) return '$weekday $from';
    final sameDay = end.year == start.year &&
        end.month == start.month &&
        end.day == start.day;
    final to = DateFormat(sameDay ? 'HH:mm' : 'd MMM HH:mm', 'sv_SE').format(end);
    return '$weekday $from–$to';
  }

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
