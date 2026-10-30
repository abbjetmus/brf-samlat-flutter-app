import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../invoice_payment_status.dart';
import 'invoice_detail_page.dart';

class InvoicesListPage extends CompositionWidget {
  static const String path = '/invoices';

  const InvoicesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final invoicesStore = inject(invoicesStoreKey);

    onMounted(() {
      invoicesStore.getAllInvoices();
    });

    return (context) {
      final invoices = invoicesStore.invoices.value;
      final loading = invoicesStore.listLoading.value;
      final loadingMore = invoicesStore.loadingMore.value;
      final hasMore = invoicesStore.hasMore.value;

      return GradientScaffold(
        title: 'Fakturor',
        body: Column(
          children: [
            const HelpTip(
              id: 'invoices',
              text:
                'Här ser du avierna till din bostad och om de är betalda. '
                'Betala via din internetbank till kontonumret på avin och '
                'ange OCR-numret. Tryck på en avi för att se '
                'betalningsuppgifterna.',
            ),
            Expanded(
              child: loading && invoices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : invoices.isEmpty
            ? const Center(child: Text('Inga fakturor.'))
            : PaginatedListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: invoices.length,
                hasMore: hasMore,
                loadingMore: loadingMore,
                onLoadMore: invoicesStore.fetchNextInvoices,
                onRefresh: invoicesStore.getAllInvoices,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  final status = InvoicePaymentStatus.of(invoice);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        'Fakturadatum: ${AppDateUtils.formatDate(invoice.invoiceDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          'Förfallodatum: ${AppDateUtils.formatDate(invoice.invoiceDueDate)}',
                          if (invoice.amount > 0) formatKr(invoice.amount),
                        ].join(' · '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InvoiceStatusChip(status),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push(
                        '${InvoiceDetailPage.path}/${invoice.id}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    };
  }
}
