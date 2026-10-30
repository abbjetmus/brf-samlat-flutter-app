import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/models/pocketbase_models.dart';

class ProxyInput {
  final String residenceId;
  final String? proxyUserId;
  final String proxyName;
  final PlatformFile? document;

  const ProxyInput({
    required this.residenceId,
    required this.proxyUserId,
    required this.proxyName,
    required this.document,
  });
}

/// Registrera en fullmakt: vem som röstar för bostaden. Ombudet väljs bland
/// föreningens användare (kan rösta i appen) eller anges med namn (röstar på
/// plats). [onSave] returnerar ett felmeddelande eller null.
class ProxySheet extends CompositionWidget {
  const ProxySheet({
    super.key,
    required this.residences,
    required this.users,
    required this.perMember,
    required this.onSave,
  });

  final List<ResidencesRecord> residences;
  final List<UsersRecord> users;
  final bool perMember;
  final Future<String?> Function(ProxyInput input) onSave;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();

    final residenceId = ref<String?>(
      props.value.residences.isEmpty ? null : props.value.residences.first.id,
    );
    // 'user' = användare i föreningen, 'name' = annan person.
    final mode = ref<String>('user');
    final proxyUserId = ref<String?>(null);
    final (nameController, name, _) = useTextEditingController();
    final document = ref<PlatformFile?>(null);
    final saving = ref(false);
    final error = ref<String?>(null);

    final canSave = computed(
      () =>
          !saving.value &&
          residenceId.value != null &&
          (mode.value == 'user'
              ? proxyUserId.value != null
              : name.value.trim().isNotEmpty),
    );

    Future<void> pickDocument() async {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      );
      final file = result?.files.firstOrNull;
      if (file?.bytes != null) document.value = file;
    }

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        ProxyInput(
          residenceId: residenceId.value!,
          proxyUserId: mode.value == 'user' ? proxyUserId.value : null,
          proxyName: mode.value == 'name' ? name.value.trim() : '',
          document: document.value,
        ),
      );
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
    }

    return (context) {
      final p = props.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Registrera fullmakt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            p.perMember
                ? 'Ombudet röstar för dig på stämman. Styrelsen godkänner '
                      'fullmakten innan den gäller.'
                : 'Ombudet röstar för bostaden på stämman. Styrelsen '
                      'godkänner fullmakten innan den gäller.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (p.residences.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: residenceId.value,
              decoration: const InputDecoration(
                labelText: 'Bostad',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in p.residences)
                  DropdownMenuItem(value: r.id, child: Text(r.streetAddress)),
              ],
              onChanged: (v) => residenceId.value = v,
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'user',
                icon: Icon(Icons.person_outline),
                label: Text('Medlem i föreningen'),
              ),
              ButtonSegment(
                value: 'name',
                icon: Icon(Icons.badge_outlined),
                label: Text('Annan person'),
              ),
            ],
            selected: {mode.value},
            onSelectionChanged: (s) => mode.value = s.first,
          ),
          const SizedBox(height: 12),
          if (mode.value == 'user')
            DropdownButtonFormField<String>(
              initialValue: proxyUserId.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ombud',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final u in p.users)
                  DropdownMenuItem(
                    value: u.id,
                    child: Text(
                      u.name.isNotEmpty ? u.name : (u.email ?? u.id),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => proxyUserId.value = v,
            )
          else ...[
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ombudets namn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ett ombud utan konto röstar på plats och visar fullmakten där.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: Text(
              document.value?.name ?? 'Bifoga undertecknad fullmakt (valfritt)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('PDF eller bild'),
            trailing: document.value == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Ta bort',
                    onPressed: () => document.value = null,
                  ),
            onTap: saving.value ? null : pickDocument,
          ),
          if (error.value != null) ...[
            const SizedBox(height: 8),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave.value ? save : null,
            child: saving.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrera'),
          ),
        ],
      );
    };
  }
}
