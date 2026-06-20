import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_text_editor.dart';

const _placeTypes = ['Lägenhet', 'Tvättstuga', 'Festlokal', 'Bastu', 'Annat'];
const _slotDurationTypes = ['Minuter', 'Timmar', 'Dagar'];
const _bookingPeriodTypes = ['Dag', 'Vecka', 'Månad', 'År'];

class CreatePlacePage extends CompositionWidget {
  static const String path = '/places/create';
  static const String editPath = '/places/edit';

  /// When non-null the page edits the existing place instead of creating one.
  final String? placeId;

  const CreatePlacePage({super.key, this.placeId});

  @override
  Widget Function(BuildContext) setup() {
    final placesStore = inject(placesStoreKey);
    final isEdit = placeId != null;
    final existing = (isEdit && placesStore.currentPlace.value?.id == placeId)
        ? placesStore.currentPlace.value
        : null;

    final (nameController, _, __) = useTextEditingController();
    final (streetController, a3, a4) = useTextEditingController();
    final (zipController, a5, a6) = useTextEditingController();
    final (localityController, a7, a8) = useTextEditingController();
    final (startTimeController, a9, a10) = useTextEditingController();
    final (endTimeController, a11, a12) = useTextEditingController();
    final (slotLengthController, a13, a14) = useTextEditingController();
    final (priceController, a15, a16) = useTextEditingController();
    final (capacityController, a17, a18) = useTextEditingController();
    final (allowedCountController, a19, a20) = useTextEditingController();
    final loading = ref(false);
    final contextRef = useContext();

    final placeType = ref<String?>(existing?.placeType);
    final slotDurationType = ref<String>(
      existing?.bookingSlotDurationType.isNotEmpty == true
          ? existing!.bookingSlotDurationType
          : 'Timmar',
    );
    final allowedPeriodType = ref<String?>(existing?.allowedBookingPeriodType);

    // Description is rich text (HTML), edited via the WYSIWYG editor.
    var descriptionHtml = existing?.description ?? '';
    final descriptionReady = ref(!isEdit || existing != null);

    void populateFrom(dynamic place) {
      nameController.text = place.name;
      streetController.text = place.streetAddress;
      zipController.text = place.zipCode;
      localityController.text = place.locality;
      startTimeController.text = place.bookingStartTime;
      endTimeController.text = place.bookingEndTime;
      slotLengthController.text = place.bookingSlotDurationLength.toString();
      priceController.text = place.pricePerSlot != null
          ? (place.pricePerSlot as double).toStringAsFixed(0)
          : '';
      capacityController.text = place.maxRoomCapacity?.toString() ?? '';
      allowedCountController.text =
          place.allowedNumberOfBookingsPerPeriod?.toString() ?? '';
      placeType.value = place.placeType;
      slotDurationType.value =
          (place.bookingSlotDurationType as String).isNotEmpty
          ? place.bookingSlotDurationType
          : 'Timmar';
      allowedPeriodType.value = place.allowedBookingPeriodType;
      descriptionHtml = place.description ?? '';
    }

    if (existing != null) {
      populateFrom(existing);
    } else if (!isEdit) {
      startTimeController.text = '08:00';
      endTimeController.text = '22:00';
      slotLengthController.text = '1';
    }

    onMounted(() async {
      if (isEdit && existing == null) {
        await placesStore.getPlace(placeId!);
        final place = placesStore.currentPlace.value;
        if (place != null && place.id == placeId) {
          populateFrom(place);
        }
        descriptionReady.value = true;
      }
    });

    Future<void> save() async {
      if (nameController.text.trim().isEmpty) return;
      if (streetController.text.trim().isEmpty) return;

      final price = double.tryParse(priceController.text.replaceAll(',', '.'));
      final capacity = int.tryParse(capacityController.text);
      final allowedCount = int.tryParse(allowedCountController.text);

      loading.value = true;
      final success = isEdit
          ? await placesStore.updatePlace(
              id: placeId!,
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              placeType: placeType.value,
              bookingStartTime: startTimeController.text.trim(),
              bookingEndTime: endTimeController.text.trim(),
              bookingSlotDurationLength:
                  int.tryParse(slotLengthController.text) ?? 1,
              bookingSlotDurationType: slotDurationType.value,
              maxRoomCapacity: capacity,
              pricePerSlot: price,
              allowedBookingPeriodType: allowedPeriodType.value,
              allowedNumberOfBookingsPerPeriod: allowedCount,
            )
          : await placesStore.createPlace(
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              placeType: placeType.value,
              bookingStartTime: startTimeController.text.trim(),
              bookingEndTime: endTimeController.text.trim(),
              bookingSlotDurationLength:
                  int.tryParse(slotLengthController.text) ?? 1,
              bookingSlotDurationType: slotDurationType.value,
              maxRoomCapacity: capacity,
              pricePerSlot: price,
              allowedBookingPeriodType: allowedPeriodType.value,
              allowedNumberOfBookingsPerPeriod: allowedCount,
            );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Lokal uppdaterad!' : 'Lokal skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera lokal.'
                    : 'Kunde inte skapa lokal.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera lokal' : 'Skapa lokal',
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
            DropdownButtonFormField<String?>(
              initialValue: placeType.value,
              decoration: const InputDecoration(
                labelText: 'Lokaltyp',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ingen'),
                ),
                ...<String>{
                  ..._placeTypes,
                  if (placeType.value != null) placeType.value!,
                }.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
              ],
              onChanged: (value) => placeType.value = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: slotDurationType.value,
              decoration: const InputDecoration(
                labelText: 'Bokningstyp',
                border: OutlineInputBorder(),
              ),
              items: <String>{..._slotDurationTypes, slotDurationType.value}
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) {
                if (value != null) slotDurationType.value = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: slotLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Antal per bokning',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Pris per bokning (kr)',
                helperText: 'Lämna blank om gratis',
                border: OutlineInputBorder(),
              ),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Starttid',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Sluttid',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max antal personer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: allowedPeriodType.value,
              decoration: const InputDecoration(
                labelText: 'Typ av begränsningsperiod',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ingen begränsning'),
                ),
                ...<String>{
                  ..._bookingPeriodTypes,
                  if (allowedPeriodType.value != null) allowedPeriodType.value!,
                }.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
              ],
              onChanged: (value) => allowedPeriodType.value = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: allowedCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Antal tillåtna bokningar per period',
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
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa lokal'),
            ),
          ],
        ),
      ),
    );
  }
}
