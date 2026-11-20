import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import '../../core/models/pocketbase_models.dart';

/// Shared helpers for "Sök i chatten" and "Media och filer".

String senderName(ChatMessagesRecord m) {
  final name = m.senderUser?.name ?? '';
  return name.isNotEmpty ? name : 'Okänd';
}

/// "18 nov 21:36", with the year when it isn't this year.
String formatChatWhen(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final pattern = d.year == DateTime.now().year
      ? 'd MMM HH:mm'
      : 'd MMM y HH:mm';
  return DateFormat(pattern, 'sv_SE').format(d);
}

/// A part of [text] around the first match of [query], with "…" where cut.
String excerptAround(String text, String query) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ');
  final at = flat.toLowerCase().indexOf(query.toLowerCase());
  final start = at > 60 ? at - 60 : 0;
  final end = (at < 0 ? 0 : at) + query.length + 140;
  final cut = end < flat.length ? end : flat.length;
  return '${start > 0 ? '…' : ''}${flat.substring(start, cut)}${cut < flat.length ? '…' : ''}';
}

/// [text] as spans with every (case-insensitive) match of [query] in [style].
TextSpan highlightMatches(String text, String query, TextStyle style) {
  if (query.isEmpty) return TextSpan(text: text);
  final lower = text.toLowerCase();
  final q = query.toLowerCase();
  final spans = <TextSpan>[];
  var i = 0;
  while (true) {
    final at = lower.indexOf(q, i);
    if (at < 0) {
      spans.add(TextSpan(text: text.substring(i)));
      break;
    }
    if (at > i) spans.add(TextSpan(text: text.substring(i, at)));
    spans.add(TextSpan(text: text.substring(at, at + q.length), style: style));
    i = at + q.length;
  }
  return TextSpan(children: spans);
}
