import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'create_parking_lot_page.dart';

class ParkingLotDetailPage extends CompositionWidget {
  static const String path = '/parking/detail';

  final String parkingLotId;

  const ParkingLotDetailPage({super.key, required this.parkingLotId});

  @override
  Widget Function(BuildContext) setup() {
    final parkingStore = inject(parkingStoreKey);
    final residencesStore = inject(residencesStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      parkingStore.getParkingLot(parkingLotId);
      parkingStore.getParkingSpaces(parkingLotId);
      residencesStore.getAllResidences();
    });

    // Create (space == null) or edit an existing parking space.
    Future<void> showSpaceDialog({ParkingSpacesRecord? space}) async {
      final context = contextRef.value;
      if (context == null) return;

      final isEdit = space != null;
      final nameController = TextEditingController(text: space?.name ?? '');
      bool hasCharging = space?.hasChargingStation ?? false;
      final residences = residencesStore.residencesList.value;
      String? residenceId =
          (space?.residence != null && space!.residence!.isNotEmpty)
          ? space.residence
          : null;
      // Drop an assigned residence that is no longer in the loaded list so the
      // dropdown has a valid value.
      if (residenceId != null && !residences.any((r) => r.id == residenceId)) {
        residenceId = null;
      }
      String? startDate =
          (space?.parkingStartDate != null && space!.parkingStartDate!.isNotEmpty)
          ? space.parkingStartDate
          : null;

      String formatDate(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              isEdit ? 'Redigera parkeringsplats' : 'Ny parkeringsplats',
            ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: residenceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tilldela bostad',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Ingen (ledig)'),
                      ),
                      ...residences.map(
                        (r) => DropdownMenuItem<String?>(
                          value: r.id,
                          child: Text(
                            r.streetAddress,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => residenceId = value);
                    },
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Startdatum'),
                    subtitle: Text(
                      startDate != null
                          ? startDate!.split('T').first
                          : 'Inte angivet',
                    ),
                    trailing: startDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => startDate = null),
                          )
                        : const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(startDate ?? '') ?? DateTime(2024),
                        firstDate: DateTime(1950),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => startDate = formatDate(picked));
                      }
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
                child: Text(isEdit ? 'Spara' : 'Skapa'),
              ),
            ],
          ),
        ),
      );

      if (result == true && nameController.text.trim().isNotEmpty) {
        if (isEdit) {
          await parkingStore.updateParkingSpace(
            id: space.id,
            name: nameController.text.trim(),
            residence: residenceId,
            hasChargingStation: hasCharging,
            parkingStartDate: startDate,
            parkingLotId: parkingLotId,
          );
        } else {
          await parkingStore.createParkingSpace(
            parkingLotId: parkingLotId,
            name: nameController.text.trim(),
            residence: residenceId,
            hasChargingStation: hasCharging,
            parkingStartDate: startDate,
          );
        }
      }

      nameController.dispose();
    }

    return (context) {
      final lot = parkingStore.currentParkingLot.value;
      final spaces = parkingStore.parkingSpaces.value;
      final residences = residencesStore.residencesList.value;
      final loading = parkingStore.loading.value;

      String? residenceLabel(String? id) {
        if (id == null || id.isEmpty) return null;
        for (final r in residences) {
          if (r.id == id) return r.streetAddress;
        }
        return null;
      }
      final canCreate = authStore.hasPermission(
        'parking_spaces',
        CrudOperation.create,
      );
      final canUpdate = authStore.hasPermission(
        'parking_lots',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'parking_lots',
        CrudOperation.delete,
      );
      final canUpdateSpace = authStore.hasPermission(
        'parking_spaces',
        CrudOperation.update,
      );
      final canDeleteSpace = authStore.hasPermission(
        'parking_spaces',
        CrudOperation.delete,
      );

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
            if (canUpdate || canDelete)
              EntityActionMenu.header(
                actions: [
                  if (canUpdate)
                    EntityAction.update(() {
                      context.push(
                        '${CreateParkingLotPage.editPath}/${lot.id}',
                      );
                    }),
                  if (canDelete)
                    EntityAction.delete(() async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Radera parkering',
                        message:
                            'Är du säker på att du vill radera denna parkering?',
                        okLabel: 'Radera',
                        okColor: Colors.red,
                      );
                      if (confirmed) {
                        await parkingStore.deleteParkingLot(lot.id);
                        final ctx = contextRef.value;
                        if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
                      }
                    }),
                ],
              ),
          ],
          floatingActionButton: canCreate
              ? FloatingActionButton(
                  onPressed: () => showSpaceDialog(),
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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (lot.description != null &&
                              lot.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            RichDescription(html: lot.description!),
                          ],
                          const SizedBox(height: 16),
                          const Divider(),
                          _infoRow(
                            Icons.location_on,
                            '${lot.streetAddress}, ${lot.zipCode} ${lot.locality}',
                          ),
                          _infoRow(Icons.local_parking, lot.parkingType),
                          if (lot.capacity != null)
                            _infoRow(
                              Icons.space_dashboard,
                              '${lot.capacity} platser',
                            ),
                          if (lot.pricePerBookingPeriod != null &&
                              lot.pricePerBookingPeriod! > 0)
                            _infoRow(
                              Icons.payments,
                              '${lot.pricePerBookingPeriod!.toStringAsFixed(0)} kr/${lot.bookingPeriodType ?? 'period'}',
                            ),
                        ],
                      ),
                    ),

                    // Spaces tab
                    spaces.isEmpty
                        ? const Center(
                            child: Text('Inga parkeringsplatser ännu.'),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                parkingStore.getParkingSpaces(parkingLotId),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: spaces.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final space = spaces[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    onTap: canUpdateSpace
                                        ? () => showSpaceDialog(space: space)
                                        : () => _showSpaceDetails(
                                            context,
                                            space,
                                            residenceLabel(space.residence),
                                          ),
                                    leading: Icon(
                                      space.hasChargingStation
                                          ? Icons.ev_station
                                          : Icons.local_parking,
                                    ),
                                    title: Text(space.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        space.residence != null &&
                                                space.residence!.isNotEmpty
                                            ? Text(
                                                residenceLabel(
                                                      space.residence,
                                                    ) ??
                                                    'Bostad tilldelad',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              )
                                            : Text(
                                                'Ledig',
                                                style: TextStyle(
                                                  color: Colors.green[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                        if (space.hasChargingStation)
                                          Text(
                                            'Laddstation',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (space.parkingStartDate != null &&
                                            space.parkingStartDate!.isNotEmpty)
                                          Text(
                                            'Startdatum: ${space.parkingStartDate!.split('T').first}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing:
                                        (canUpdateSpace || canDeleteSpace)
                                        ? EntityActionMenu(
                                            actions: [
                                              if (canUpdateSpace)
                                                EntityAction.update(
                                                  () => showSpaceDialog(
                                                    space: space,
                                                  ),
                                                ),
                                              if (canDeleteSpace)
                                                EntityAction.delete(() async {
                                                  final confirmed =
                                                      await showConfirmDialog(
                                                        context,
                                                        title: 'Radera plats',
                                                        message:
                                                            'Är du säker på att du vill radera denna parkeringsplats?',
                                                        okLabel: 'Radera',
                                                        okColor: Colors.red,
                                                      );
                                                  if (confirmed) {
                                                    await parkingStore
                                                        .deleteParkingSpace(
                                                          space.id,
                                                          parkingLotId,
                                                        );
                                                  }
                                                }),
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

/// Read-only details for a parking space, shown to users without edit rights so
/// they can still view the space information.
void _showSpaceDetails(
  BuildContext context,
  ParkingSpacesRecord space,
  String? residenceLabel,
) {
  final hasResidence = space.residence != null && space.residence!.isNotEmpty;
  showAppBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              space.hasChargingStation
                  ? Icons.ev_station
                  : Icons.local_parking,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                space.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _infoRow(
          Icons.home_outlined,
          hasResidence ? (residenceLabel ?? 'Bostad tilldelad') : 'Ledig',
        ),
        _infoRow(
          space.hasChargingStation ? Icons.ev_station : Icons.power_off,
          space.hasChargingStation ? 'Laddstation' : 'Ingen laddstation',
        ),
        if (space.parkingStartDate != null &&
            space.parkingStartDate!.isNotEmpty)
          _infoRow(
            Icons.event,
            'Startdatum: ${space.parkingStartDate!.split('T').first}',
          ),
      ],
    ),
  );
}
