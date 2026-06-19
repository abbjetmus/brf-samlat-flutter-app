import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CreateResidencePage extends CompositionWidget {
  static const String path = '/residences/create';
  static const String editPath = '/residences/edit';

  /// When non-null the page edits the existing residence instead of creating one.
  final String? residenceId;

  const CreateResidencePage({super.key, this.residenceId});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final usersStore = inject(usersStoreKey);
    final isEdit = residenceId != null;
    final existing =
        (isEdit && residencesStore.currentResidence.value?.id == residenceId)
        ? residencesStore.currentResidence.value
        : null;

    final (streetController, _, __) = useTextEditingController();
    final (zipController, a1, a2) = useTextEditingController();
    final (localityController, a3, a4) = useTextEditingController();
    final loading = ref(false);
    final selectedResidenceType = ref<String>(
      existing?.residenceType ?? 'Lägenhet',
    );
    final moveInDate = ref<String?>(existing?.moveInDate);
    // Association members available for assignment, and the currently selected ids.
    final associationUsers = ref<List<UsersRecord>>([]);
    final selectedUserIds = ref<List<String>>(
      List<String>.from(existing?.users ?? const []),
    );
    final contextRef = useContext();

    void populateFrom(dynamic r) {
      streetController.text = r.streetAddress;
      zipController.text = r.zipCode;
      localityController.text = r.locality;
      selectedResidenceType.value = (r.residenceType as String).isNotEmpty
          ? r.residenceType
          : 'Lägenhet';
      moveInDate.value = r.moveInDate;
      selectedUserIds.value = List<String>.from(r.users as List<String>);
    }

    if (existing != null) {
      populateFrom(existing);
    }

    onMounted(() async {
      associationUsers.value = await usersStore.getAllAssociationUsers();
      if (isEdit && existing == null) {
        await residencesStore.getResidence(residenceId!);
        final r = residencesStore.currentResidence.value;
        if (r != null && r.id == residenceId) {
          populateFrom(r);
        }
      }
    });

    Future<void> save() async {
      if (streetController.text.trim().isEmpty) return;

      loading.value = true;
      final success = isEdit
          ? await residencesStore.updateResidence(
              id: residenceId!,
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              residenceType: selectedResidenceType.value,
              moveInDate: moveInDate.value,
              users: selectedUserIds.value,
            )
          : await residencesStore.createResidence(
              streetAddress: streetController.text.trim(),
              zipCode: zipController.text.trim(),
              locality: localityController.text.trim(),
              residenceType: selectedResidenceType.value,
              moveInDate: moveInDate.value,
              users: selectedUserIds.value,
            );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Bostad uppdaterad!' : 'Bostad skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera bostad.'
                    : 'Kunde inte skapa bostad.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera bostad' : 'Skapa bostad',
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
              items:
                  <String>{
                    'Lägenhet',
                    'Radhus',
                    'Villa',
                    'Parhus',
                    'Kedjehus',
                    selectedResidenceType.value,
                  }.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedResidenceType.value = value;
                }
              },
            ),
            const SizedBox(height: 16),
            _MoveInDateField(
              value: moveInDate.value,
              onChanged: (v) => moveInDate.value = v,
            ),
            const SizedBox(height: 24),
            Text(
              'Boende',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tilldela användare från föreningen',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (associationUsers.value.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Inga användare i föreningen.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: associationUsers.value.map((u) {
                  final selected = selectedUserIds.value.contains(u.id);
                  return FilterChip(
                    label: Text(u.name.isNotEmpty ? u.name : (u.email ?? u.id)),
                    selected: selected,
                    onSelected: (value) {
                      final next = List<String>.from(selectedUserIds.value);
                      if (value) {
                        if (!next.contains(u.id)) next.add(u.id);
                      } else {
                        next.remove(u.id);
                      }
                      selectedUserIds.value = next;
                    },
                  );
                }).toList(),
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
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa bostad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date picker field for the residence move-in date. Stores the value as a
/// `yyyy-MM-dd` string (matching the PocketBase date field), empty = unset.
class _MoveInDateField extends StatelessWidget {
  const _MoveInDateField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  String _format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final display = hasValue ? value!.split('T').first : 'Inte angivet';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Inflyttningsdatum',
        border: const OutlineInputBorder(),
        suffixIcon: hasValue
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today),
      ),
      child: InkWell(
        onTap: () async {
          final initial = hasValue
              ? DateTime.tryParse(value!) ?? DateTime(2024)
              : DateTime(2024);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(_format(picked));
        },
        child: Text(display),
      ),
    );
  }
}
