import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import '../../invoices/invoice_payment_status.dart';
import '../../invoices/pages/invoice_detail_page.dart';
import '../invoice_overview_store.dart';
import '../widgets/invoice_payments_sheet.dart';
import '../widgets/register_payment_sheet.dart';

/// Fakturaöversikt (admin): every invoice in the association with status,
/// period and search filters, totals, and payment registration. Mirrors
/// /admin/invoice-overview on the web; the CSV and SIE exports stay web-only.
class InvoiceOverviewPage extends CompositionWidget {
  static const String path = '/invoice-overview';

  const InvoiceOverviewPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final store = InvoiceOverviewStore(inject(pocketBaseKey), authStore);
    final theme = useTheme();
    final contextRef = useContext();
    final presets = invoicePeriodPresets();
    final savingId = ref<String?>(null);

    // Default period: this year, like the web.
    store.from.value = presets.first.from;
    store.to.value = presets.first.to;

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    // Load when the association is known, and again whenever a filter changes.
    watch(
      () => (
        authStore.association.value?.id,
        store.from.value,
        store.to.value,
        store.status.value,
      ),
      (value, _) {
        final assocId = value.$1;
        if (assocId != null && assocId.isNotEmpty) store.refresh();
      },
      immediate: true,
    );

    Timer? debounce;
    onUnmounted(() => debounce?.cancel());
    void onSearch(String text) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), () {
        store.search.value = text;
        store.refresh();
      });
    }

    Future<void> markPaid(OverviewInvoice row) async {
      savingId.value = row.invoice.id;
      final message = await store.markPaid(row.invoice.id);
      savingId.value = null;
      if (message != null) {
        snack(message);
        return;
      }
      snack('Avin är markerad som betald');
      await store.refresh();
    }

    Future<void> registerPayment(OverviewInvoice row) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => RegisterPaymentSheet(
          invoice: row.invoice,
          onSave:
              ({
                required amount,
                required paymentDate,
                required reference,
                required note,
              }) => store.registerPayment(
                invoiceId: row.invoice.id,
                amount: amount,
                paymentDate: paymentDate,
                reference: reference,
                note: note,
              ),
        ),
      );
      if (saved == true) {
        snack('Betalningen är registrerad');
        await store.refresh();
      }
    }

    Future<void> showPayments(OverviewInvoice row, bool canDelete) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      var changed = false;
      await showAppBottomSheet<void>(
        context: ctx,
        builder: (_) => InvoicePaymentsSheet(
          invoice: row.invoice,
          loadPayments: () => store.payments(row.invoice.id),
          deletePayment: store.deletePayment,
          canDelete: canDelete,
          onChanged: () => changed = true,
        ),
      );
      if (changed) await store.refresh();
    }

    return (context) {
      final scheme = theme.value.colorScheme;
      final rows = store.invoices.value;
      final totals = store.totals.value;
      final canWrite = authStore.hasPermission(
        'invoice_payments',
        CrudOperation.create,
      );
      final canDeletePayments = authStore.hasPermission(
        'invoice_payments',
        CrudOperation.delete,
      );
      final listLoading = store.loading.value;

      final header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HelpTip(
            id: 'invoice-overview',
            padding: EdgeInsets.only(bottom: 12),
            text:
                'Här ser du alla avier i föreningen. När pengarna syns på kontot '
                'trycker du på Markera som betald (hela beloppet, dagens datum) '
                'eller väljer Registrera betalning i menyn för ett annat belopp '
                'eller datum. En obetald avi efter förfallodagen visas som Förfallen.',
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final preset in presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(preset.title),
                      selected:
                          store.from.value == preset.from &&
                          store.to.value == preset.to,
                      onSelected: (_) {
                        store.from.value = preset.from;
                        store.to.value = preset.to;
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in InvoiceStatusFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: store.status.value == filter,
                      showCheckmark: false,
                      onSelected: (_) => store.status.value = filter,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SearchField(hintText: 'Sök OCR eller adress', onChanged: onSearch),
          const SizedBox(height: 12),
          _TotalsGrid(totals: totals, scheme: scheme),
          if (store.error.value != null) ...[
            const SizedBox(height: 8),
            Text(
              store.error.value!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Export till bokföring (SIE och CSV) finns på webben.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (listLoading && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Inga avier matchar filtret.')),
            ),
        ],
      );

      return GradientScaffold(
        title: 'Fakturaöversikt',
        subtitle: 'Avier, betalningar och vad som är kvar att betala',
        body: PaginatedListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: rows.length + 1,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.loadMore,
          onRefresh: store.refresh,
          itemBuilder: (context, index) {
            if (index == 0) return header;
            final row = rows[index - 1];
            return _InvoiceRow(
              row: row,
              canWrite: canWrite,
              saving: savingId.value == row.invoice.id,
              onMarkPaid: () => markPaid(row),
              onRegister: () => registerPayment(row),
              onPayments: () => showPayments(row, canDeletePayments),
              onOpen: () =>
                  context.push('${InvoiceDetailPage.path}/${row.invoice.id}'),
            );
          },
        ),
      );
    };
  }
}

class _TotalsGrid extends StatelessWidget {
  final InvoiceOverviewTotals totals;
  final ColorScheme scheme;

  const _TotalsGrid({required this.totals, required this.scheme});

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, String value, String subtitle, Color? color) {
      return Expanded(
        child: Card(
          margin: const EdgeInsets.all(3),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tile(
              'Fakturerat',
              formatKr(totals.invoiced),
              '${totals.count} avier',
              null,
            ),
            tile(
              'Inbetalt',
              formatKr(totals.paid),
              'Registrerade betalningar',
              Colors.green,
            ),
          ],
        ),
        Row(
          children: [
            tile(
              'Utestående',
              formatKr(totals.outstanding),
              'Kvar att betala',
              totals.outstanding > 0 ? Colors.orange : null,
            ),
            tile(
              'Förfallet',
              formatKr(totals.overdue),
              '${totals.overdueCount} efter förfallodagen',
              totals.overdue > 0 ? scheme.error : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final OverviewInvoice row;
  final bool canWrite;
  final bool saving;
  final VoidCallback onMarkPaid;
  final VoidCallback onRegister;
  final VoidCallback onPayments;
  final VoidCallback onOpen;

  const _InvoiceRow({
    required this.row,
    required this.canWrite,
    required this.saving,
    required this.onMarkPaid,
    required this.onRegister,
    required this.onPayments,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final invoice = row.invoice;
    final status = InvoicePaymentStatus.of(invoice);
    final outstanding = invoice.outstanding;
    final caption = [
      if (row.residenceAddress.isNotEmpty) row.residenceAddress,
      if (invoice.ocr.isNotEmpty) 'OCR ${invoice.ocr}',
      'Förfaller ${AppDateUtils.formatDate(invoice.invoiceDueDate)}',
    ].join(' · ');
    final amounts = [
      formatKr(invoice.amount),
      'betalt ${formatKr(invoice.paidAmount)}',
      outstanding < 0
          ? 'överbetalt ${formatKr(-outstanding)}'
          : 'kvar ${formatKr(outstanding)}',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _capitalize(invoicePeriodLabel(invoice.invoiceDate)),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InvoiceStatusChip(status),
                  EntityActionMenu(
                    actions: [
                      EntityAction(
                        icon: Icons.open_in_new,
                        label: 'Öppna avin',
                        onSelected: onOpen,
                      ),
                      if (canWrite)
                        EntityAction(
                          icon: Icons.add_card_outlined,
                          label: 'Registrera betalning',
                          onSelected: onRegister,
                        ),
                      EntityAction(
                        icon: Icons.payments_outlined,
                        label: 'Betalningar',
                        onSelected: onPayments,
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  caption,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  amounts,
                  style: TextStyle(
                    fontSize: 13,
                    color: outstanding < 0 ? Colors.orange : null,
                  ),
                ),
              ),
              if (canWrite && outstanding > 0) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: saving ? null : onMarkPaid,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Markera som betald'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
