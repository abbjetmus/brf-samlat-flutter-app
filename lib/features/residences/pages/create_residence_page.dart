import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CreateResidencePage extends CompositionWidget {
  static const String path = '/residences/create';

  const CreateResidencePage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final (streetController, _, __) = useTextEditingController();
    final (zipController, a1, a2) = useTextEditingController();
    final (localityController, a3, a4) = useTextEditingController();
    final loading = ref(false);
    final selectedResidenceType = ref<String>('Lägenhet');
    final contextRef = useContext();

    Future<void> createResidence() async {
      if (streetController.text.trim().isEmpty) return;

      loading.value = true;
      final success = await residencesStore.createResidence(
        streetAddress: streetController.text.trim(),
        zipCode: zipController.text.trim(),
        locality: localityController.text.trim(),
        residenceType: selectedResidenceType.value,
      );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bostad skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunde inte skapa bostad.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: 'Skapa bostad',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              initialValue: selectedResidenceType.value,
              decoration: const InputDecoration(
                labelText: 'Bostadstyp',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Lägenhet', child: Text('Lägenhet')),
                DropdownMenuItem(value: 'Radhus', child: Text('Radhus')),
                DropdownMenuItem(value: 'Villa', child: Text('Villa')),
              ],
              onChanged: (value) {
                if (value != null) {
                  selectedResidenceType.value = value;
                }
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading.value ? null : createResidence,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Skapa bostad'),
            ),
          ],
        ),
      ),
    );
  }
}
