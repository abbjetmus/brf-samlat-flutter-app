import 'package:add_2_calendar/add_2_calendar.dart' as a2c;

/// "Lägg till i kalender" i appen.
///
/// Öppnar telefonens egen "ny händelse"-vy (EventKit på iOS, kalenderappens
/// INSERT-intent på Android) via `add_2_calendar`, ifylld med händelsen. Det är
/// bättre än att dela en .ics-fil: Google Kalender på Android kan inte importera
/// .ics, och på iOS är Kalender inget delningsmål för filer.
///
/// Prenumeration på hela kalendern (iCal) finns under Kalender → ⋮ →
/// "Prenumerera på kalendern" (`CalendarSubscriptionSheet`).
class CalendarExport {
  CalendarExport._();

  /// Webbappens adress, för länken tillbaka till mötet/inlägget i händelsen.
  static const webBaseUrl = 'https://brfsamlat.se';

  static String webUrl(String path) => '$webBaseUrl$path';

  /// Returnerar false bara om kalendervyn inte kunde öppnas (t.ex. ingen
  /// kalenderapp). Pluginens eget resultat är false även när användaren
  /// avbryter i iOS-vyn, så det räknas inte som ett fel.
  static Future<bool> addEvent({
    required String title,
    required DateTime start,
    DateTime? end,
    String description = '',
    String location = '',
    String? url,
  }) async {
    // Saknas slut (eller ligger det inte efter start): en timme, som i
    // prenumerationen och webben.
    final effectiveEnd = end == null || !end.isAfter(start)
        ? start.add(const Duration(hours: 1))
        : end;
    final text = htmlToPlainText(description);
    // Android har inget URL-fält, så länken läggs även sist i beskrivningen.
    final fullDescription = [
      if (text.isNotEmpty) text,
      if (url != null && url.isNotEmpty) url,
    ].join('\n\n');

    try {
      await a2c.Add2Calendar.addEvent2Cal(
        a2c.Event(
          title: title.trim().isEmpty ? 'Händelse' : title.trim(),
          description: fullDescription,
          location: location,
          startDate: start.toLocal(),
          endDate: effectiveEnd.toLocal(),
          iosParams: a2c.IOSParams(url: url),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Rich text (Quill/TipTap-HTML) → ren text för händelsens beskrivning.
  static String htmlToPlainText(String html) {
    if (html.trim().isEmpty) return '';
    final withBreaks = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(
          RegExp(r'</(p|div|h[1-6]|li|blockquote|tr)>', caseSensitive: false),
          '\n',
        );
    final text = withBreaks
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m[1]!)),
        )
        .replaceAllMapped(
          RegExp(r'&([a-zA-Z]+);'),
          (m) => _entities[m[1]] ?? m[0]!,
        );
    return text
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static const _entities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'aring': 'å',
    'auml': 'ä',
    'ouml': 'ö',
    'Aring': 'Å',
    'Auml': 'Ä',
    'Ouml': 'Ö',
    'eacute': 'é',
    'ndash': '–',
    'mdash': '—',
    'hellip': '…',
  };
}
