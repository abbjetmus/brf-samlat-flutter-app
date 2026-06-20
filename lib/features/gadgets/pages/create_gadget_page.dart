import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_text_editor.dart';

const _slotDurationTypes = ['Minuter', 'Timmar', 'Dagar'];
const _bookingPeriodTypes = ['Dag', 'Vecka', 'Månad', 'År'];

class CreateGadgetPage extends CompositionWidget {
  static const String path = '/gadgets/create';
  static const String editPath = '/gadgets/edit';

  /// When non-null the page edits the existing gadget instead of creating one.
  final String? gadgetId;

  const CreateGadgetPage({super.key, this.gadgetId});

  @override
  Widget Function(BuildContext) setup() {
    final gadgetsStore = inject(gadgetsStoreKey);
    final isEdit = gadgetId != null;
    final existing =
        (isEdit && gadgetsStore.currentGadget.value?.id == gadgetId)
        ? gadgetsStore.currentGadget.value
        : null;

    final (nameController, _, __) = useTextEditingController();
    final (streetController, a3, a4) = useTextEditingController();
    final (zipController, a5, a6) = useTextEditingController();
    final (localityController, a7, a8) = useTextEditingController();
    final (startTimeController, a9, a10) = useTextEditingController();
    final (endTimeController, a11, a12) = useTextEditingController();
    final (slotLengthController, a13, a14) = useTextEditingController();
    final (priceController, a15, a16) = useTextEditingController();
    final (allowedCountController, a17, a18) = useTextEditingController();
    final loading = ref(false);
    final contextRef = useContext();

    final slotDurationType = ref<String>(
      existing?.bookingSlotDurationType.isNotEmpty == true
          ? existing!.bookingSlotDurationType
          : 'Timmar',
    );
    final allowedPeriodType = ref<String?>(existing?.allowedBookingPeriodType);

    // Description is rich text (HTML), edited via the WYSIWYG editor.
    var descriptionHtml = existing?.description ?? '';
    final descriptionReady = ref(!isEdit || existing != null);

    void populateFrom(dynamic gadget) {
      nameController.text = gadget.name;
      streetController.text = gadget.streetAddress;
      zipController.text = gadget.zipCode;
      localityController.text = gadget.locality;
      startTimeController.text = gadget.bookingStartTime;
      endTimeController.text = gadget.bookingEndTime;
      slotLengthController.text = gadget.bookingSlotDurationLength.toString();
      priceController.text = gadget.pricePerSlot != null
          ? (gadget.pricePerSlot as double).toStringAsFixed(0)
          : '';
      allowedCountController.text =
          gadget.allowedNumberOfBookingsPerPeriod?.toString() ?? '';
      slotDurationType.value =
          (gadget.bookingSlotDurationType as String).isNotEmpty
          ? gadget.bookingSlotDurationType
          : 'Timmar';
      allowedPeriodType.value = gadget.allowedBookingPeriodType;
      descriptionHtml = gadget.description ?? '';
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
        await gadgetsStore.getGadget(gadgetId!);
        final gadget = gadgetsStore.currentGadget.value;
        if (gadget != null && gadget.id == gadgetId) {
          populateFrom(gadget);
        }
        descriptionReady.value = true;
      }
    });

    Future<void> save() async {
      if (nameController.text.trim().isEmpty) return;
      if (streetController.text.trim().isEmpty) return;

      final price = double.tryParse(priceController.text.replaceAll(',', '.'));
      final allowedCount = int.tryParse(allowedCountController.text);

      loading.value = true;
      final success = isEdit
          ? await gadgetsStore.updateGadget(
              id: gadgetId!,
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              bookingStartTime: startTimeController.text.trim(),
              bookingEndTime: endTimeController.text.trim(),
              bookingSlotDurationLength:
                  int.tryParse(slotLengthController.text) ?? 1,
              bookingSlotDurationType: slotDurationType.value,
              pricePerSlot: price,
              allowedBookingPeriodType: allowedPeriodType.value,
              allowedNumberOfBookingsPerPeriod: allowedCount,
            )
          : await gadgetsStore.createGadget(
              name: nameController.text.trim(),
              description: descriptionHtml,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              bookingStartTime: startTimeController.text.trim(),
              bookingEndTime: endTimeController.text.trim(),
              bookingSlotDurationLength:
                  int.tryParse(slotLengthController.text) ?? 1,
              bookingSlotDurationType: slotDurationType.value,
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
              content: Text(isEdit ? 'Pryl uppdaterad!' : 'Pryl skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera pryl.'
                    : 'Kunde inte skapa pryl.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera pryl' : 'Skapa pryl',
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
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa pryl'),
            ),
          ],
        ),
      ),
    );
  }
}
