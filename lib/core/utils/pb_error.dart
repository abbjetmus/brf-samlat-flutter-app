import 'package:pocketbase/pocketbase.dart' show ClientException;

/// Turns a PocketBase error into a message the member can act on.
///
/// The server's hooks answer in Swedish ("Tiden är redan bokad.", "Du saknar
/// behörighet för denna åtgärd."), and those are shown as they are. PocketBase's
/// own English defaults ("Failed to create record.") are replaced by a summary
/// of the field errors, a message for the status code, or [fallback].
///
/// Keep in sync with the Nuxt app's helper (brf-samlat-nuxt-app), which follows
/// the same rules.
String pbErrorMessage(Object error, String fallback) {
  if (error is! ClientException) return fallback;

  if (error.statusCode == 0) {
    return error.isAbort
        ? fallback
        : 'Kunde inte nå servern. Kontrollera din anslutning och försök igen.';
  }

  final message = error.response['message'];
  if (message is String) {
    final trimmed = message.trim();
    if (trimmed.isNotEmpty && _isSwedish(trimmed)) return trimmed;
  }

  final data = error.response['data'];
  if (data is Map && data.isNotEmpty) {
    final parts = data.entries.map((entry) {
      final field = entry.key.toString();
      final value = entry.value;
      final code = value is Map ? (value['code'] ?? '').toString() : '';
      final fieldMessage = value is Map
          ? (value['message'] ?? '').toString().trim().replaceAll(
              RegExp(r'[.!]+$'),
              '',
            )
          : '';
      return '${_fieldLabel(field)} ${_phrase(code, fieldMessage)}';
    });
    return '${parts.join('; ')}.';
  }

  switch (error.statusCode) {
    case 403:
      return 'Du saknar behörighet för denna åtgärd.';
    case 429:
      return 'För många försök. Vänta en stund och försök igen.';
    case 401:
      return 'Du behöver logga in igen.';
  }

  return fallback;
}

final _swedishChars = RegExp('[åäöÅÄÖé]');
final _englishWords = RegExp(
  r"\b(the|failed|record|request|invalid|please|missing|not|cannot|can't|only|must|you|your|and|to|of|is|are|with|something|wrong|found|allowed|unauthorized|forbidden|too|many|requests|bad|value|blank|error|server|already|exists|required|be|this|an|for|has|have|been|was|wasn't)\b",
  caseSensitive: false,
);

/// False for PocketBase's English defaults, true for the hooks' own messages.
bool _isSwedish(String text) =>
    _swedishChars.hasMatch(text) || !_englishWords.hasMatch(text);

const _fieldLabels = {
  'name': 'Namn',
  'email': 'E-post',
  'phone': 'Telefon',
  'password': 'Lösenord',
  'passwordConfirm': 'Lösenordsbekräftelse',
  'username': 'Användarnamn',
  'title': 'Titel',
  'description': 'Beskrivning',
  'content': 'Innehåll',
  'street_address': 'Adress',
  'zip_code': 'Postnummer',
  'locality': 'Ort',
  'start_at': 'Starttid',
  'end_at': 'Sluttid',
  'residence': 'Bostad',
  'place': 'Lokal',
  'gadget': 'Pryl',
  'answers': 'Svar',
  'attachments': 'Bilagor',
  'images': 'Bilder',
  'comment': 'Kommentar',
};

String _fieldLabel(String field) {
  final label = _fieldLabels[field];
  if (label != null) return label;
  final spaced = field.replaceAll('_', ' ');
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String _phrase(String code, String message) {
  switch (code) {
    case 'validation_required':
      return 'måste fyllas i';
    case 'validation_is_email':
    case 'validation_invalid_email':
      return 'är inte en giltig e-postadress';
  }
  if (code.contains('unique')) return 'används redan';
  switch (code) {
    case 'validation_length_out_of_range':
    case 'validation_length_too_short':
    case 'validation_length_too_long':
    case 'validation_min_text_constraint':
    case 'validation_max_text_constraint':
      return 'har fel längd';
    case 'validation_invalid_format':
    case 'validation_match_invalid':
      return 'har fel format';
    case 'validation_values_mismatch':
      return 'matchar inte';
    case 'validation_missing_rel_records':
    case 'validation_invalid_relation':
      return 'hänvisar till något som inte finns';
    case 'validation_file_size_limit':
      return 'är för stor';
    case 'validation_invalid_mime_type':
      return 'har en filtyp som inte stöds';
    case 'validation_too_many_values':
      return 'har för många värden';
  }
  if (code.contains('date')) return 'är inget giltigt datum';
  if (code.contains('range') ||
      code.contains('min_') ||
      code.contains('max_')) {
    return 'har ett ogiltigt värde';
  }
  if (message.isNotEmpty && _isSwedish(message)) return message;
  return 'är ogiltigt';
}
