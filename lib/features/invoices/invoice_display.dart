import '../../core/models/pocketbase_models.dart';

typedef InvoiceDisplayItem = ({String description, double price});

/// What an invoice shows. Reads the template snapshot frozen on the invoice
/// when it was created; falls back to the template's (and residence's) current
/// data only for invoices without one. Shared by [InvoiceDetailPage] and
/// [InvoicePdf].
class InvoiceDisplay {
  const InvoiceDisplay({
    required this.items,
    required this.total,
    this.associationName,
    this.bankAccountType,
    this.bankAccountNumber,
    this.message,
    this.residenceAddress,
  });

  final List<InvoiceDisplayItem> items;
  final double total;
  final String? associationName;
  final String? bankAccountType;
  final String? bankAccountNumber;
  final String? message;

  /// Recipients (if known) and address on one line, e.g.
  /// "Anna Andersson/Erik Andersson, Fregattvägen 7A, 112 34 Stockholm".
  final String? residenceAddress;

  factory InvoiceDisplay.resolve(
    InvoicesRecord invoice, {
    InvoiceTemplatesRecord? template,
    ResidencesRecord? residence,
    String? associationName,
  }) {
    final snapshot = invoice.templateSnapshot;
    final rawItems = snapshot != null
        ? snapshot.invoiceItems
        : (template?.invoiceItems ?? const []);
    final items = rawItems
        .whereType<Map>()
        .map(
          (e) => (
            description: (e['description'] as String?) ?? '',
            price: num.tryParse('${e['price']}')?.toDouble() ?? 0.0,
          ),
        )
        .toList();

    String? address;
    if (snapshot != null && snapshot.hasResidence) {
      address = [
        if (snapshot.recipients.isNotEmpty) snapshot.recipients.join('/'),
        snapshot.residenceStreetAddress ?? '',
        '${snapshot.residenceZipCode ?? ''} ${snapshot.residenceLocality ?? ''}'
            .trim(),
      ].where((s) => s.isNotEmpty).join(', ');
    } else if (residence != null) {
      address =
          '${residence.streetAddress}, ${residence.zipCode} ${residence.locality}';
    }

    String? nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

    return InvoiceDisplay(
      items: items,
      total: items.fold<double>(0, (sum, e) => sum + e.price),
      associationName:
          nonEmpty(snapshot?.associationName) ?? nonEmpty(associationName),
      bankAccountType: nonEmpty(
        snapshot != null ? snapshot.bankAccountType : template?.bankAccountType,
      ),
      bankAccountNumber: nonEmpty(
        snapshot != null
            ? snapshot.bankAccountNumber
            : template?.bankAccountNumber,
      ),
      message: nonEmpty(
        snapshot != null ? snapshot.message : template?.message,
      ),
      residenceAddress: nonEmpty(address),
    );
  }
}
