import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import '../contractors_store.dart';
import '../widgets/contractor_sheet.dart';

/// Leverantörer: the association's contractors (plumbers, electricians …),
/// gated on the `contractors` permission. Issues are sent to them from the
/// issue detail page ("Skicka till leverantör").
class ContractorsPage extends CompositionWidget {
  static const String path = '/contractors';

  const ContractorsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final store = ContractorsStore(inject(pocketBaseKey), authStore);
    final theme = useTheme();
    final contextRef = useContext();

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    watch(
      () => (authStore.association.value?.id, store.trade.value),
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

    Future<void> openEdit([ContractorsRecord? contractor]) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => ContractorSheet(
          contractor: contractor,
          onSave: (body) => store.save(contractor?.id, body),
        ),
      );
      if (saved == true) {
        snack('Leverantören är sparad');
        await store.refresh();
      }
    }

    Future<void> remove(ContractorsRecord contractor) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera leverantör',
        message:
            'Vill du radera "${contractor.name}"? Tidigare utskick finns kvar på '
            'ärendena, men länkar som redan skickats fortsätter att gälla tills '
            'de går ut eller återkallas.',
        okLabel: 'Radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      final message = await store.delete(contractor.id);
      snack(message ?? 'Leverantören är raderad');
      if (message == null) await store.refresh();
    }

    return (context) {
      final scheme = theme.value.colorScheme;
      final items = store.contractors.value;
      final canCreate = authStore.hasPermission(
        'contractors',
        CrudOperation.create,
      );
      final canUpdate = authStore.hasPermission(
        'contractors',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'contractors',
        CrudOperation.delete,
      );
      final filtering =
          store.search.value.trim().isNotEmpty || store.trade.value != null;

      final header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HelpTip(
            id: 'contractors',
            padding: EdgeInsets.only(bottom: 12),
            text:
                'Lägg upp föreningens leverantörer här. På en felanmälan väljer du '
                'sedan Skicka till leverantör i menyn. Leverantören får en '
                'personlig länk och kan meddela mottagen, planerad och åtgärdad, '
                'och uppdateringarna blir kommentarer på ärendet.',
          ),
          SearchField(hintText: 'Sök leverantör', onChanged: onSearch),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Alla yrken'),
                    selected: store.trade.value == null,
                    showCheckmark: false,
                    onSelected: (_) => store.trade.value = null,
                  ),
                ),
                for (final t in contractorTrades)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(t.title),
                      selected: store.trade.value == t.value,
                      showCheckmark: false,
                      onSelected: (_) => store.trade.value = t.value,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (store.loading.value && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filtering
                        ? 'Inga leverantörer matchar sökningen.'
                        : 'Inga leverantörer än. Lägg till rörmokare, '
                              'elektriker, hissfirma och andra som föreningen '
                              'anlitar, så kan du skicka felanmälningar direkt '
                              'till dem.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      );

      return GradientScaffold(
        title: 'Leverantörer',
        subtitle: 'Föreningens hantverkare och serviceföretag',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => openEdit(),
                tooltip: 'Ny leverantör',
                child: const Icon(Icons.add),
              )
            : null,
        body: PaginatedListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          itemCount: items.length + 1,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.loadMore,
          onRefresh: store.refresh,
          itemBuilder: (context, index) {
            if (index == 0) return header;
            final c = items[index - 1];
            final trade = contractorTradeMeta(c.trade);
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(trade.icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            [
                              trade.title,
                              if (c.contactName.isNotEmpty) c.contactName,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    launchUrl(Uri.parse('mailto:${c.email}')),
                                icon: const Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                ),
                                label: Text(c.email),
                              ),
                              if (c.phone.isNotEmpty)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => launchUrl(
                                    Uri.parse(
                                      'tel:${c.phone.replaceAll(' ', '')}',
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.phone_outlined,
                                    size: 16,
                                  ),
                                  label: Text(c.phone),
                                ),
                            ],
                          ),
                          if (c.notes.isNotEmpty)
                            Text(
                              c.notes,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    EntityActionMenu(
                      actions: [
                        if (canUpdate)
                          EntityAction.update(
                            () => openEdit(c),
                            label: 'Redigera',
                          ),
                        if (canDelete) EntityAction.delete(() => remove(c)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    };
  }
}
