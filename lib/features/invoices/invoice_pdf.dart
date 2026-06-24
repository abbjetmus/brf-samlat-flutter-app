import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/pocketbase_models.dart';
import '../../core/utils/date_utils.dart';

/// Builds a printable invoice PDF and opens the native share/print sheet via
/// [Printing.sharePdf]. Mirrors [InvoiceDetailPage]: dates, residence address,
/// invoice items with totals, and bank account information.
class InvoicePdf {
  const InvoicePdf._();

  static Future<void> share(
    InvoicesRecord invoice,
    InvoiceTemplatesRecord template, {
    String? residenceAddress,
    String? associationName,
  }) async {
    final bytes = await _build(
      invoice,
      template,
      residenceAddress: residenceAddress,
      associationName: associationName,
    );
    final fileDate = AppDateUtils.formatDate(invoice.invoiceDate)
        .replaceAll(' ', '_')
        .replaceAll('/', '-');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'faktura_$fileDate.pdf',
    );
  }

  static Future<Uint8List> _build(
    InvoicesRecord invoice,
    InvoiceTemplatesRecord template, {
    String? residenceAddress,
    String? associationName,
  }) async {
    final doc = pw.Document();

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    final items = (template.invoiceItems ?? [])
        .whereType<Map>()
        .map((e) => _InvoiceItem(
              description: (e['description'] as String?) ?? '',
              price: num.tryParse('${e['price']}')?.toDouble() ?? 0,
            ))
        .toList();
    final total = items.fold<double>(0, (sum, e) => sum + e.price);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          _header(
            associationName: associationName,
            invoiceId: invoice.id,
            invoiceDate: AppDateUtils.formatDate(invoice.invoiceDate),
            dispatchDate: AppDateUtils.formatDate(invoice.invoiceDispatchDate),
            dueDate: AppDateUtils.formatDate(invoice.invoiceDueDate),
            residenceAddress: residenceAddress,
            bankAccountType: template.bankAccountType,
            bankAccountNumber: template.bankAccountNumber,
          ),
          if (items.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _itemsTable(items, total),
          ],
          if (template.message != null && template.message!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _message(template.message!),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header({
    String? associationName,
    required String invoiceId,
    required String invoiceDate,
    required String dispatchDate,
    required String dueDate,
    String? residenceAddress,
    String? bankAccountType,
    String? bankAccountNumber,
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
          'Faktura',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _metaRow('Faktura-ID', invoiceId),
                  _metaRow('Fakturadatum', invoiceDate),
                  _metaRow('Utskicksdatum', dispatchDate),
                  _metaRow('Förfallodatum', dueDate),
                  if (bankAccountType != null && bankAccountType.isNotEmpty)
                    _metaRow('Kontotyp', bankAccountType),
                  if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
                    _metaRow('Kontonummer', bankAccountNumber),
                ],
              ),
            ),
            if (residenceAddress != null && residenceAddress.isNotEmpty)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Fakturaadress',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      residenceAddress,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
            width: 100,
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

  static pw.Widget _itemsTable(List<_InvoiceItem> items, double total) {
    const cellStyle = pw.TextStyle(fontSize: 11);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Artiklar',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: null,
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
                ),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('Beskrivning',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('Belopp',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                ),
              ],
            ),
            ...items.map(
              (item) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom:
                        pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(item.description, style: cellStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(
                      '${item.price.toStringAsFixed(0)} kr',
                      textAlign: pw.TextAlign.right,
                      style: cellStyle,
                    ),
                  ),
                ],
              ),
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey800, width: 1.2),
                ),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text('Totalt',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    '${total.toStringAsFixed(0)} kr',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _message(String html) {
    final text = _htmlToText(html);
    if (text.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Meddelande',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
      ],
    );
  }

  static String _htmlToText(String html) {
    if (html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'</\s*(p|div|h[1-6])\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

class _InvoiceItem {
  const _InvoiceItem({required this.description, required this.price});
  final String description;
  final double price;
}
