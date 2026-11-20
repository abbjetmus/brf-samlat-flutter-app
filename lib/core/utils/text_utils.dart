/// Plain-text helpers for rich-text (HTML) content.
class TextUtils {
  static final _tags = RegExp(r'<[^>]*>');
  static final _space = RegExp(r'\s+');
  static const _entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };

  /// A short plain-text excerpt of [html] (tags removed, whitespace collapsed,
  /// cut at a word boundary with "…").
  static String excerpt(String html, {int maxLength = 160}) {
    var text = html
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>|<br\s*/?>'), ' ')
        .replaceAll(_tags, '');
    _entities.forEach((k, v) => text = text.replaceAll(k, v));
    text = text.replaceAll(_space, ' ').trim();
    if (text.length <= maxLength) return text;
    final cut = text.substring(0, maxLength);
    final lastSpace = cut.lastIndexOf(' ');
    return '${(lastSpace > maxLength * 0.6 ? cut.substring(0, lastSpace) : cut).trimRight()}…';
  }

  /// Initials for an avatar: "Adam Nilsson" → "AN".
  static String initials(String name) {
    final parts = name.trim().split(_space).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The first image's src in rich-text [html] (posts can have images inline).
String? firstImageUrl(String html) {
  final m = RegExp(r'''<img[^>]+src=["']([^"']+)["']''').firstMatch(html);
  return m?.group(1);
}
