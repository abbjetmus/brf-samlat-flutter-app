import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/search_field.dart';
import 'gadget_detail_page.dart';
import 'create_gadget_page.dart';

class GadgetsListPage extends CompositionWidget {
  static const String path = '/gadgets';

  const GadgetsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final gadgetsStore = inject(gadgetsStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      gadgetsStore.getAllGadgets();
    });

    return (context) {
      final gadgets = gadgetsStore.gadgetsList.value;
      final loading = gadgetsStore.loading.value;
      final canCreate = authStore.hasPermission(
        'gadgets',
        CrudOperation.create,
      );

      final query = searchQuery.value.trim().toLowerCase();
      final filteredGadgets = query.isEmpty
          ? gadgets
          : gadgets
                .where(
                  (g) =>
                      g.name.toLowerCase().contains(query) ||
                      (g.description ?? '').toLowerCase().contains(query) ||
                      g.streetAddress.toLowerCase().contains(query),
                )
                .toList();

      return GradientScaffold(
        title: 'Prylar',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreateGadgetPage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && gadgets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : gadgets.isEmpty
            ? const Center(child: Text('Inga prylar ännu.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchField(
                      hintText: 'Sök pryl...',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredGadgets.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : RefreshIndicator(
                            onRefresh: () => gadgetsStore.getAllGadgets(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredGadgets.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final gadget = filteredGadgets[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.handyman_outlined,
                                    ),
                                    title: Text(
                                      gadget.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      gadget.streetAddress,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push(
                                      '${GadgetDetailPage.path}/${gadget.id}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      );
    };
  }
}
