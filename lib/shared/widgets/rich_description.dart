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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        color ?? theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final linkColor = theme.colorScheme.primary;

    return Html(
      data: html,
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
        'p': Style(margin: Margins.only(bottom: 8)),
        'p:last-child': Style(margin: Margins.zero),
        'ul, ol': Style(margin: Margins.only(bottom: 8, left: 16)),
        'li': Style(margin: Margins.only(bottom: 4)),
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
