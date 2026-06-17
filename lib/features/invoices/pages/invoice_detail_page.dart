import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';

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
      final loading = invoicesStore.loading.value;
      final canDelete = authStore.hasPermission('invoices', CrudOperation.delete);

      if (loading && invoice == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Faktura')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (invoice == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Faktura')),
          body: const Center(child: Text('Faktura hittades inte.')),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Faktura'),
          actions: [
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera faktura',
                    message: 'Är du säker på att du vill radera denna faktura?',
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
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fakturadetaljer',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Divider(),
              _infoRow(Icons.calendar_today, 'Fakturadatum', AppDateUtils.formatDate(invoice.invoiceDate)),
              _infoRow(Icons.send, 'Utskicksdatum', AppDateUtils.formatDate(invoice.invoiceDispatchDate)),
              _infoRow(Icons.event, 'Förfallodatum', AppDateUtils.formatDate(invoice.invoiceDueDate)),
              _infoRow(Icons.home_outlined, 'Bostad', invoice.residence.isNotEmpty ? invoice.residence : '-'),
              _infoRow(Icons.description_outlined, 'Mall', template?.id ?? '-'),
              if (template?.message != null && template!.message!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Meddelande',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  template.message!,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      );
    };
  }
}

Widget _infoRow(IconData icon, String label, String value) {
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
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
