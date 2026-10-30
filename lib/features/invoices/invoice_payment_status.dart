import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/pocketbase_models.dart';

/// Betalstatus som den visas för en avi. `payment_status` räknas om av
/// servern från invoice_payments; "Förfallen" lagras inte utan följer av att
/// avin inte är betald och förfallodagen har passerat.
enum InvoicePaymentStatus {
  obetald('Obetald', Colors.grey, Icons.schedule),
  delbetald('Delbetald', Colors.orange, Icons.timelapse),
  betald('Betald', Colors.green, Icons.check_circle_outline),
  forfallen('Förfallen', Colors.red, Icons.error_outline);

  const InvoicePaymentStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static InvoicePaymentStatus of(InvoicesRecord invoice, {DateTime? now}) {
    if (invoice.paymentStatus == 'betald') return betald;
    final today = DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());
    final due = invoice.invoiceDueDate;
    if (due.isNotEmpty && due.compareTo(today) < 0) return forfallen;
    return invoice.paymentStatus == 'delbetald' ? delbetald : obetald;
  }
}

/// 5800 -> "5 800 kr", 5800.5 -> "5 800,50 kr".
String formatKr(double amount) {
  final hasCents = (amount * 100).round() % 100 != 0;
  final format = NumberFormat.currency(
    locale: 'sv_SE',
    symbol: 'kr',
    decimalDigits: hasCents ? 2 : 0,
  );
  return format.format(amount);
}

/// "bankgiro" -> "Bankgiro".
String accountTypeLabel(String? type) {
  switch (type) {
    case 'bankgiro':
      return 'Bankgiro';
    case 'plusgiro':
      return 'Plusgiro';
    case null:
    case '':
      return 'Konto';
    default:
      return type[0].toUpperCase() + type.substring(1);
  }
}

/// Liten statusetikett för listor och detaljsidan.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip(this.status, {super.key});

  final InvoicePaymentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              color: status.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
