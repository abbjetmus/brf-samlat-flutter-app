import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CreateGadgetPage extends CompositionWidget {
  static const String path = '/gadgets/create';

  const CreateGadgetPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final gadgetsStore = inject(gadgetsStoreKey);
    final (nameController, _, __) = useTextEditingController();
    final (descriptionController, a1, a2) = useTextEditingController();
    final (streetController, a3, a4) = useTextEditingController();
    final (zipController, a5, a6) = useTextEditingController();
    final (localityController, a7, a8) = useTextEditingController();
    final (startTimeController, a9, a10) = useTextEditingController();
    final (endTimeController, a11, a12) = useTextEditingController();
    final (slotLengthController, a13, a14) = useTextEditingController();
    final loading = ref(false);
    final contextRef = useContext();

    startTimeController.text = '08:00';
    endTimeController.text = '22:00';
    slotLengthController.text = '1';

    Future<void> createGadget() async {
      if (nameController.text.trim().isEmpty) return;
      if (streetController.text.trim().isEmpty) return;

      loading.value = true;
      final success = await gadgetsStore.createGadget(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        streetAddress: streetController.text.trim(),
        zipCode: zipController.text.trim(),
        locality: localityController.text.trim(),
        bookingStartTime: startTimeController.text.trim(),
        bookingEndTime: endTimeController.text.trim(),
        bookingSlotDurationLength: int.tryParse(slotLengthController.text) ?? 1,
        bookingSlotDurationType: 'Timmar',
      );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pryl skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunde inte skapa pryl.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: 'Skapa pryl',
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
            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Beskrivning',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
              controller: slotLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bokningsslot (timmar)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading.value ? null : createGadget,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Skapa pryl'),
            ),
          ],
        ),
      ),
    );
  }
}
