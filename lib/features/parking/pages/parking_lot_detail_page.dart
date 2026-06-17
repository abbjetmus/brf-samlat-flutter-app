import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class ParkingLotDetailPage extends CompositionWidget {
  static const String path = '/parking/detail';

  final String parkingLotId;

  const ParkingLotDetailPage({super.key, required this.parkingLotId});

  @override
  Widget Function(BuildContext) setup() {
    final parkingStore = inject(parkingStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      parkingStore.getParkingLot(parkingLotId);
      parkingStore.getParkingSpaces(parkingLotId);
    });

    Future<void> showAddSpaceDialog() async {
      final context = contextRef.value;
      if (context == null) return;

      final nameController = TextEditingController();
      bool hasCharging = false;

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Ny parkeringsplats'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Namn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Laddstation'),
                    value: hasCharging,
                    onChanged: (value) {
                      setState(() {
                        hasCharging = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Skapa'),
              ),
            ],
          ),
        ),
      );

      if (result == true && nameController.text.trim().isNotEmpty) {
        await parkingStore.createParkingSpace(
          parkingLotId: parkingLotId,
          name: nameController.text.trim(),
          hasChargingStation: hasCharging,
        );
      }

      nameController.dispose();
    }

    return (context) {
      final lot = parkingStore.currentParkingLot.value;
      final spaces = parkingStore.parkingSpaces.value;
      final loading = parkingStore.loading.value;
      final canCreate = authStore.hasPermission('parking_spaces', CrudOperation.create);
      final canDelete = authStore.hasPermission('parking_lots', CrudOperation.delete);
      final canDeleteSpace = authStore.hasPermission('parking_spaces', CrudOperation.delete);

      if (loading && lot == null) {
        return const GradientScaffold(
          title: 'Parkering',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (lot == null) {
        return const GradientScaffold(
          title: 'Parkering',
          body: Center(child: Text('Parkering hittades inte.')),
        );
      }

      return DefaultTabController(
        length: 2,
        child: GradientScaffold(
          title: lot.name,
          actions: [
            if (canDelete)
              HeaderIconButton(
                icon: Icons.delete_outline,
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera parkering',
                    message: 'Är du säker på att du vill radera denna parkering?',
                    okLabel: 'Radera',
                    okColor: Colors.red,
                  );
                  if (confirmed) {
                    await parkingStore.deleteParkingLot(lot.id);
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
              ),
          ],
          floatingActionButton: canCreate
              ? FloatingActionButton(
                  onPressed: showAddSpaceDialog,
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Information'),
                  Tab(text: 'Platser'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
              // Info tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (lot.description != null && lot.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      RichDescription(html: lot.description!),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    _infoRow(Icons.location_on, '${lot.streetAddress}, ${lot.zipCode} ${lot.locality}'),
                    _infoRow(Icons.local_parking, lot.parkingType),
                    if (lot.capacity != null)
                      _infoRow(Icons.space_dashboard, '${lot.capacity} platser'),
                    if (lot.pricePerBookingPeriod != null && lot.pricePerBookingPeriod! > 0)
                      _infoRow(Icons.payments, '${lot.pricePerBookingPeriod!.toStringAsFixed(0)} kr/${lot.bookingPeriodType ?? 'period'}'),
                  ],
                ),
              ),

              // Spaces tab
              spaces.isEmpty
                  ? const Center(child: Text('Inga parkeringsplatser ännu.'))
                  : RefreshIndicator(
                      onRefresh: () => parkingStore.getParkingSpaces(parkingLotId),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: spaces.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final space = spaces[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: Icon(
                                space.hasChargingStation
                                    ? Icons.ev_station
                                    : Icons.local_parking,
                              ),
                              title: Text(space.name),
                              subtitle: space.residence != null && space.residence!.isNotEmpty
                                  ? Text(
                                      'Bostad tilldelad',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    )
                                  : Text(
                                      'Ledig',
                                      style: TextStyle(color: Colors.green[600], fontSize: 12),
                                    ),
                              trailing: canDeleteSpace
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'delete') {
                                          final confirmed = await showConfirmDialog(
                                            context,
                                            title: 'Radera plats',
                                            message: 'Är du säker på att du vill radera denna parkeringsplats?',
                                            okLabel: 'Radera',
                                            okColor: Colors.red,
                                          );
                                          if (confirmed) {
                                            await parkingStore.deleteParkingSpace(space.id, parkingLotId);
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Radera', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}

Widget _infoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
