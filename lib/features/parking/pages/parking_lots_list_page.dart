import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import 'parking_lot_detail_page.dart';
import 'create_parking_lot_page.dart';

class ParkingLotsListPage extends CompositionWidget {
  static const String path = '/parking';

  const ParkingLotsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final parkingStore = inject(parkingStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      parkingStore.getAllParkingLots();
    });

    return (context) {
      final lots = parkingStore.parkingLotsList.value;
      final loading = parkingStore.loading.value;
      final canCreate = authStore.hasPermission('parking_lots', CrudOperation.create);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Parkeringar'),
        ),
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
                : RefreshIndicator(
                    onRefresh: () => parkingStore.getAllParkingLots(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: lots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final lot = lots[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: const Icon(Icons.local_parking_outlined),
                            title: Text(
                              lot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              lot.parkingType,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('${ParkingLotDetailPage.path}/${lot.id}'),
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
