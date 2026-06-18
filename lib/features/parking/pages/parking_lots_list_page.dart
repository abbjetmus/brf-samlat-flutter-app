import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import 'parking_lot_detail_page.dart';
import 'create_parking_lot_page.dart';

class ParkingLotsListPage extends CompositionWidget {
  static const String path = '/parking';

  const ParkingLotsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final parkingStore = inject(parkingStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      parkingStore.getAllParkingLots();
    });

    return (context) {
      final lots = parkingStore.parkingLotsList.value;
      final loading = parkingStore.listLoading.value;
      final loadingMore = parkingStore.loadingMore.value;
      final hasMore = parkingStore.hasMore.value;
      final canCreate = authStore.hasPermission(
        'parking_lots',
        CrudOperation.create,
      );

      final query = searchQuery.value.trim().toLowerCase();
      final filteredLots = query.isEmpty
          ? lots
          : lots
                .where(
                  (l) =>
                      l.name.toLowerCase().contains(query) ||
                      l.parkingType.toLowerCase().contains(query),
                )
                .toList();

      return GradientScaffold(
        title: 'Parkeringar',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreateParkingLotPage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && lots.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : lots.isEmpty
            ? const Center(child: Text('Inga parkeringar ännu.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchField(
                      hintText: 'Sök parkering...',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredLots.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredLots.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: parkingStore.fetchNextParkingLots,
                            onRefresh: parkingStore.getAllParkingLots,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final lot = filteredLots[index];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.local_parking_outlined,
                                  ),
                                  title: Text(
                                    lot.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    lot.parkingType,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                    '${ParkingLotDetailPage.path}/${lot.id}',
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
