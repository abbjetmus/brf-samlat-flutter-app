import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/rich_description.dart';
import '../invoice_display.dart';
import '../invoice_payment_status.dart';
import '../invoice_pdf.dart';

class InvoiceDetailPage extends CompositionWidget {
  static const String path = '/invoices/detail';

  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  Widget Function(BuildContext) setup() {
    final invoicesStore = inject(invoicesStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      invoicesStore.getInvoice(invoiceId);
    });

    return (context) {
      final invoice = invoicesStore.currentInvoice.value;
      final template = invoicesStore.invoiceTemplate.value;
      final residence = invoicesStore.currentResidence.value;
      final loading = invoicesStore.loading.value;
      final payments = invoicesStore.payments.value;
      final canDelete = authStore.hasPermission(
        'invoices',
        CrudOperation.delete,
      );

      if (loading && invoice == null) {
        return const GradientScaffold(
          title: 'Faktura',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (invoice == null) {
        return const GradientScaffold(
          title: 'Faktura',
          body: Center(child: Text('Faktura hittades inte.')),
        );
      }

      // Snapshot on the invoice, falling back to the live template/residence
      // for invoices created before snapshots existed.
      final display = InvoiceDisplay.resolve(
        invoice,
        template: template,
        residence: residence,
        associationName: authStore.association.value?.name,
      );
      final items = display.items;
      final total = display.total;
      final residenceAddress = display.residenceAddress;

      return GradientScaffold(
        title: 'Faktura',
        actions: [
          EntityActionMenu.header(
            actions: [
              if (invoice.templateSnapshot != null || template != null)
                EntityAction(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Generera PDF',
                  onSelected: () => InvoicePdf.share(invoice, display),
                ),
              if (canDelete)
                EntityAction.delete(() async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera faktura',
                    message:
                        'Är du säker på att du vill radera denna faktura?',
                    okLabel: 'Radera',
                    okColor: Colors.red,
                  );
                  if (confirmed) {
                    await invoicesStore.deleteInvoice(invoice.id);
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  }
                }),
            ],
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HelpTip(
                id: 'invoice-detail',
                padding: EdgeInsets.only(bottom: 8),
                text:
                    'Betala via din internetbank till kontonumret nedan senast '
                    'på förfallodatumet och ange OCR-numret som referens. I '
                    'menyn uppe till höger kan du skapa en PDF av avin.',
              ),
              // Dates
              _InfoRow(Icons.calendar_today, 'Fakturadatum',
                  AppDateUtils.formatDate(invoice.invoiceDate)),
              _InfoRow(Icons.send_outlined, 'Utskicksdatum',
                  AppDateUtils.formatDate(invoice.invoiceDispatchDate)),
              _InfoRow(Icons.event_outlined, 'Förfallodatum',
                  AppDateUtils.formatDate(invoice.invoiceDueDate)),

              // Residence address
              if (residenceAddress != null) ...[
                const Divider(height: 24),
                _InfoRow(Icons.home_outlined, 'Fakturaadress', residenceAddress),
              ],

              // Betalning: konto, OCR och status. De boende betalar via sin
              // egen internetbank.
              const Divider(height: 24),
              _PaymentCard(
                invoice: invoice,
                display: display,
                payments: payments,
                onCopyOcr: () async {
                  await Clipboard.setData(ClipboardData(text: invoice.ocr));
                  final ctx = contextRef.value;
                  if (ctx != null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('OCR-numret är kopierat')),
                    );
                  }
                },
              ),

              // Invoice items
              if (items.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Artiklar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.description,
                              style: const TextStyle(fontSize: 15)),
                        ),
                        Text(
                          '${item.price.toStringAsFixed(0)} kr',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16, thickness: 1.2),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Totalt',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${total.toStringAsFixed(0)} kr',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],

              // Message
              if (display.message != null) ...[
                const Divider(height: 24),
                const Text(
                  'Meddelande',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RichDescription(html: display.message!, fontSize: 15),
              ],
            ],
          ),
        ),
      );
    };
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.invoice,
    required this.display,
    required this.payments,
    required this.onCopyOcr,
  });

  final InvoicesRecord invoice;
  final InvoiceDisplay display;
  final List<InvoicePaymentsRecord> payments;
  final VoidCallback onCopyOcr;

  @override
  Widget build(BuildContext context) {
    final status = InvoicePaymentStatus.of(invoice);
    final outstanding = invoice.outstanding;
    final paid = status == InvoicePaymentStatus.betald;
    final caption = paid && invoice.paidAt.isNotEmpty
        ? 'Betald ${invoice.paidAt}'
        : status == InvoicePaymentStatus.forfallen
            ? 'Förföll ${AppDateUtils.formatDate(invoice.invoiceDueDate)}'
            : 'Betala senast ${AppDateUtils.formatDate(invoice.invoiceDueDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Betalning',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            InvoiceStatusChip(status),
          ],
        ),
        const SizedBox(height: 2),
        Text(caption, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        if (display.bankAccountNumber != null)
          _InfoRow(
            Icons.account_balance_outlined,
            accountTypeLabel(display.bankAccountType),
            display.bankAccountNumber!,
          ),
        if (invoice.ocr.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: _InfoRow(Icons.tag_outlined, 'OCR-nummer', invoice.ocr),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Kopiera OCR-nummer',
                onPressed: onCopyOcr,
              ),
            ],
          ),
        _InfoRow(
          Icons.payments_outlined,
          outstanding < 0 ? 'Överbetalt' : 'Att betala',
          formatKr(outstanding.abs()),
        ),
        if (invoice.ocr.isNotEmpty && !paid)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Ange OCR-nummer vid betalning. Betala via din internetbank '
              'till kontonumret ovan.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Registrerade betalningar (${formatKr(invoice.paidAmount)} av '
            '${formatKr(invoice.amount)})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ...payments.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.paymentDate,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(formatKr(p.amount), style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
