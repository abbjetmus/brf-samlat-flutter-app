import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/pocketbase_models.dart';
import '../../core/utils/date_utils.dart';

/// Builds a printable meeting-protocol PDF for a board meeting (styrelsemöte)
/// and opens the native share / print sheet via [Printing.sharePdf].
///
/// The document mirrors [BoardMeetingDetailPage]: header (association, date,
/// time, address, protocol id), the agenda and protocol items, and a signature
/// block at the bottom. Because this is a board meeting the signatures are
/// ordförande + sekreterare with an optional justerare (no legally required
/// justerare, unlike a föreningsstämma).
class BoardMeetingPdf {
  const BoardMeetingPdf._();

  static Future<void> shareProtocol(
    BoardMeetingsRecord meeting, {
    String? associationName,
  }) async {
    final bytes = await _build(meeting, associationName: associationName);
    final fileDate = AppDateUtils.formatDate(meeting.startAt);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'styrelseprotokoll_$fileDate.pdf',
    );
  }

  static Future<Uint8List> _build(
    BoardMeetingsRecord meeting, {
    String? associationName,
  }) async {
    final doc = pw.Document();

    final dateStr = AppDateUtils.formatDateLong(meeting.startAt);
    final startTime = AppDateUtils.formatTime(meeting.startAt);
    final endTime = AppDateUtils.formatTime(meeting.endAt);
    final address =
        '${meeting.streetAddress}, ${meeting.zipCode} ${meeting.locality}';

    // Use Google-hosted fonts so Swedish glyphs (å ä ö) render correctly.
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          _header(
            associationName: associationName,
            dateStr: dateStr,
            time: '$startTime – $endTime',
            address: address,
            protocolId: meeting.meetingProtocolId,
          ),
          if (_hasItems(meeting.meetingAgenda)) ...[
            pw.SizedBox(height: 24),
            _itemsSection('Dagordning', meeting.meetingAgenda!),
          ],
          if (_hasItems(meeting.meetingProtocol)) ...[
            pw.SizedBox(height: 24),
            _itemsSection('Mötesprotokoll', meeting.meetingProtocol!),
          ],
          pw.SizedBox(height: 48),
          _signatures(),
        ],
      ),
    );

    return doc.save();
  }

  static bool _hasItems(List<dynamic>? items) =>
      items != null && items.isNotEmpty;

  static pw.Widget _header({
    String? associationName,
    required String dateStr,
    required String time,
    required String address,
    required String protocolId,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (associationName != null && associationName.isNotEmpty)
          pw.Text(
            associationName,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Protokoll – Styrelsemöte',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        _metaRow('Datum', dateStr),
        _metaRow('Tid', time),
        _metaRow('Plats', address),
        _metaRow('Protokoll-ID', protocolId),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsSection(String title, List<dynamic> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          String question = '';
          String answer = '';
          if (item is Map) {
            question = (item['question'] as String?)?.trim() ?? '';
            answer = (item['answer'] as String?)?.trim() ?? '';
          } else {
            answer = '$item';
          }
          answer = _htmlToText(answer);

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (question.isNotEmpty)
                  pw.Text(
                    '$index. $question',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                if (answer.isNotEmpty)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(
                      top: question.isNotEmpty ? 3 : 0,
                      left: question.isNotEmpty ? 14 : 0,
                    ),
                    child: pw.Text(
                      answer,
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Signature block for a board meeting: ordförande and sekreterare are the
  /// standard signers, with an optional justerare line.
  static pw.Widget _signatures() {
    pw.Widget line(String role) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 28),
          pw.Container(width: 240, height: 0.8, color: PdfColors.grey600),
          pw.SizedBox(height: 4),
          pw.Text(role, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            'Namnförtydligande',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Underskrifter',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        line('Ordförande'),
        line('Sekreterare'),
        line('Justerare'),
      ],
    );
  }

  /// Minimal HTML → plain-text conversion for the Tiptap-authored answers.
  /// Block tags become newlines, list items get a bullet, the rest is stripped,
  /// and the common HTML entities are decoded.
  static String _htmlToText(String html) {
    if (html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*(p|div|h[1-6])\s*>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&aring;', 'å')
        .replaceAll('&auml;', 'ä')
        .replaceAll('&ouml;', 'ö');

    // Collapse the runs of blank lines left behind by stripped block tags.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
