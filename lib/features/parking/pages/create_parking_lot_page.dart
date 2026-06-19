import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_text_editor.dart';

class CreateParkingLotPage extends CompositionWidget {
  static const String path = '/parking/create';
  static const String editPath = '/parking/edit';

  /// When non-null the page edits the existing parking lot instead of creating one.
  final String? parkingLotId;

  const CreateParkingLotPage({super.key, this.parkingLotId});

  @override
  Widget Function(BuildContext) setup() {
    final parkingStore = inject(parkingStoreKey);
    final isEdit = parkingLotId != null;
    final existing =
        (isEdit && parkingStore.currentParkingLot.value?.id == parkingLotId)
        ? parkingStore.currentParkingLot.value
        : null;

    final (nameController, _, __) = useTextEditingController();
    final (streetController, a3, a4) = useTextEditingController();
    final (zipController, a5, a6) = useTextEditingController();
    final (localityController, a7, a8) = useTextEditingController();
    final (capacityController, a9, a10) = useTextEditingController();
    final loading = ref(false);
    final selectedParkingType = ref<String>(existing?.parkingType ?? 'Garage');
    final contextRef = useContext();

    // Description is rich text (HTML), edited via the WYSIWYG editor.
    var descriptionHtml = existing?.description ?? '';
    final descriptionReady = ref(!isEdit || existing != null);

    void populateFrom(dynamic lot) {
      nameController.text = lot.name;
      streetController.text = lot.streetAddress;
      zipController.text = lot.zipCode;
      localityController.text = lot.locality;
      capacityController.text = lot.capacity?.toString() ?? '';
      selectedParkingType.value = lot.parkingType.isNotEmpty
          ? lot.parkingType
          : 'Garage';
      descriptionHtml = lot.description ?? '';
    }

    if (existing != null) {
      populateFrom(existing);
    }

    onMounted(() async {
      // Cover deep-links / stale state where the lot isn't loaded yet.
      if (isEdit && existing == null) {
        await parkingStore.getParkingLot(parkingLotId!);
        final lot = parkingStore.currentParkingLot.value;
        if (lot != null && lot.id == parkingLotId) {
          populateFrom(lot);
        }
        descriptionReady.value = true;
      }
    });

    Future<void> save() async {
      if (nameController.text.trim().isEmpty) return;
      if (streetController.text.trim().isEmpty) return;

      loading.value = true;
      final success = isEdit
          ? await parkingStore.updateParkingLot(
              id: parkingLotId!,
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              parkingType: selectedParkingType.value,
              capacity: int.tryParse(capacityController.text),
            )
          : await parkingStore.createParkingLot(
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              parkingType: selectedParkingType.value,
              capacity: int.tryParse(capacityController.text),
            );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit ? 'Parkering uppdaterad!' : 'Parkering skapad!',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera parkering.'
                    : 'Kunde inte skapa parkering.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera parkering' : 'Skapa parkering',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Namn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Beskrivning',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            if (descriptionReady.value)
              RichTextEditor(
                initialHtml: descriptionHtml,
                onChanged: (html) => descriptionHtml = html,
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: streetController,
              decoration: const InputDecoration(
                labelText: 'Gatuadress',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: zipController,
                    decoration: const InputDecoration(
                      labelText: 'Postnummer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: localityController,
                    decoration: const InputDecoration(
                      labelText: 'Ort',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedParkingType.value,
              decoration: const InputDecoration(
                labelText: 'Parkeringstyp',
                border: OutlineInputBorder(),
              ),
              items:
                  <String>{
                    'Garage',
                    'Utomhus',
                    'Carport',
                    selectedParkingType.value,
                  }.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedParkingType.value = value;
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Antal platser',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading.value ? null : save,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa parkering'),
            ),
          ],
        ),
      ),
    );
  }
}
