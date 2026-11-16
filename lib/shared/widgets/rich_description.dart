import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders rich-text HTML descriptions (Tiptap output from the admin) with
/// consistent typography across detail screens (posts, issues, places,
/// gadgets, parking, calendar events, ...).
class RichDescription extends StatelessWidget {
  const RichDescription({
    super.key,
    required this.html,
    this.fontSize = 16,
    this.color,
    this.lineHeight = 1.5,
  });

  final String html;
  final double fontSize;
  final Color? color;
  final double lineHeight;

  /// The web editor (Tiptap) saves a blank line as an empty `<p></p>`, which
  /// flutter_html collapses to nothing, so posts lost their spacing. Give
  /// every empty paragraph one line of content: a zero-width space, since
  /// flutter_html trims ordinary spaces and `&nbsp;`, and a `<br>` alone
  /// renders two lines high.
  static final RegExp _emptyParagraph = RegExp(
    r'<p(\s[^>]*)?>(\s|&nbsp;|&#160;|\u00a0|<br\s*/?>)*</p>',
    caseSensitive: false,
  );

  static String normalize(String html) =>
      html.replaceAllMapped(_emptyParagraph, (m) => '<p${m[1] ?? ''}>\u200B</p>');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        color ?? theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final linkColor = theme.colorScheme.primary;

    return Html(
      data: normalize(html),
      onLinkTap: (url, _, __) async {
        if (url == null) return;
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(fontSize),
          color: textColor,
          lineHeight: LineHeight(lineHeight),
        ),
        'p': Style(margin: Margins.only(bottom: 12)),
        'p:last-child': Style(margin: Margins.zero),
        'ul, ol': Style(margin: Margins.only(bottom: 12, left: 16)),
        'li': Style(margin: Margins.only(bottom: 4)),
        // Tiptap wraps list item text in <p>; no paragraph gap inside lists.
        'li p': Style(margin: Margins.zero),
        'a': Style(
          color: linkColor,
          textDecoration: TextDecoration.underline,
        ),
        'strong, b': Style(fontWeight: FontWeight.w700),
        'em, i': Style(fontStyle: FontStyle.italic),
        'blockquote': Style(
          margin: Margins.symmetric(vertical: 8),
          padding: HtmlPaddings.symmetric(vertical: 6, horizontal: 12),
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border(
            left: BorderSide(color: linkColor, width: 3),
          ),
          fontStyle: FontStyle.italic,
        ),
        'table': Style(
          margin: Margins.symmetric(vertical: 8),
        ),
        'th': Style(
          padding: HtmlPaddings.symmetric(vertical: 4, horizontal: 8),
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          fontWeight: FontWeight.w600,
          fontSize: FontSize(fontSize - 2),
        ),
        'td': Style(
          padding: HtmlPaddings.symmetric(vertical: 4, horizontal: 8),
          fontSize: FontSize(fontSize - 2),
        ),
      },
    );
  }
}
