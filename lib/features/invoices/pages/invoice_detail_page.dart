import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_description.dart';
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
      invoicesStore.getInvoiceTemplate();
    });

    return (context) {
      final invoice = invoicesStore.currentInvoice.value;
      final template = invoicesStore.invoiceTemplate.value;
      final residence = invoicesStore.currentResidence.value;
      final loading = invoicesStore.loading.value;
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

      final items = (template?.invoiceItems ?? [])
          .whereType<Map>()
          .map((e) => (
                description: (e['description'] as String?) ?? '',
                price: num.tryParse('${e['price']}')?.toDouble() ?? 0.0,
              ))
          .toList();
      final total = items.fold<double>(0, (sum, e) => sum + e.price);

      final residenceAddress = residence != null
          ? '${residence.streetAddress}, ${residence.zipCode} ${residence.locality}'
          : null;

      return GradientScaffold(
        title: 'Faktura',
        actions: [
          EntityActionMenu.header(
            actions: [
              if (template != null)
                EntityAction(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Generera PDF',
                  onSelected: () => InvoicePdf.share(
                    invoice,
                    template,
                    residenceAddress: residenceAddress,
                    associationName: authStore.association.value?.name,
                  ),
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

              // Bank account
              if (template?.bankAccountType != null ||
                  template?.bankAccountNumber != null) ...[
                const Divider(height: 24),
                if (template?.bankAccountType != null)
                  _InfoRow(Icons.account_balance_outlined, 'Kontotyp',
                      template!.bankAccountType!),
                if (template?.bankAccountNumber != null)
                  _InfoRow(Icons.tag_outlined, 'Kontonummer',
                      template!.bankAccountNumber!),
              ],

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
              if (template?.message != null &&
                  template!.message!.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Meddelande',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RichDescription(html: template.message!, fontSize: 15),
              ],
            ],
          ),
        ),
      );
    };
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
