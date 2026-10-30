import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/pb_error.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../invoices/invoice_payment_status.dart';

/// The registered payments on one invoice, with "Ta bort" for those allowed to
/// delete payments. [onChanged] runs after a payment was removed so the list
/// behind the sheet can refresh.
class InvoicePaymentsSheet extends CompositionWidget {
  final InvoicesRecord invoice;
  final Future<List<InvoicePaymentsRecord>> Function() loadPayments;
  final Future<String?> Function(String paymentId) deletePayment;
  final bool canDelete;
  final VoidCallback onChanged;

  const InvoicePaymentsSheet({
    super.key,
    required this.invoice,
    required this.loadPayments,
    required this.deletePayment,
    required this.canDelete,
    required this.onChanged,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final payments = ref<List<InvoicePaymentsRecord>>([]);
    final loading = ref(true);
    final error = ref<String?>(null);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      try {
        payments.value = await props.value.loadPayments();
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta betalningarna.');
      } finally {
        loading.value = false;
      }
    }

    onMounted(load);

    Future<void> remove(InvoicePaymentsRecord payment) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Ta bort betalning',
        message:
            'Vill du ta bort betalningen på ${formatKr(payment.amount)} '
            '(${payment.paymentDate})? Avins status räknas om.',
        okLabel: 'Ta bort',
        okColor: Colors.red,
      );
      if (!ok) return;
      final message = await props.value.deletePayment(payment.id);
      if (message != null) {
        error.value = message;
        return;
      }
      payments.value = payments.value.where((p) => p.id != payment.id).toList();
      props.value.onChanged();
      final c = contextRef.value;
      if (c != null && c.mounted) {
        ScaffoldMessenger.of(
          c,
        ).showSnackBar(const SnackBar(content: Text('Betalningen är borttagen')));
      }
    }

    return (context) {
      final list = payments.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Registrerade betalningar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Fakturerat ${formatKr(props.value.invoice.amount)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (loading.value)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty && error.value == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Inga betalningar är registrerade.'),
            )
          else
            for (final p in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: Text(formatKr(p.amount)),
                subtitle: Text(
                  [
                    p.paymentDate,
                    if (p.reference.isNotEmpty) p.reference,
                    if (p.note.isNotEmpty) p.note,
                  ].join(' · '),
                ),
                trailing: props.value.canDelete
                    ? EntityActionMenu(
                        actions: [
                          EntityAction.delete(
                            () => remove(p),
                            label: 'Ta bort',
                          ),
                        ],
                      )
                    : null,
              ),
          if (error.value != null) ...[
            const SizedBox(height: 8),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      );
    };
  }
}
