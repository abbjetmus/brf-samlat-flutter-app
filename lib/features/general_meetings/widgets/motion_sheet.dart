import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/file_utils.dart';
import '../general_meetings_models.dart';

/// Vad arket skickar till [MotionSheet.onSave].
class MotionInput {
  final String title;
  final String text;
  final bool submit;

  /// '' = ingen bostad.
  final String residenceId;
  final List<PlatformFile> newAttachments;

  /// Redan sparade bilagor som ska tas bort från utkastet.
  final List<String> removedAttachments;

  const MotionInput({
    required this.title,
    required this.text,
    required this.submit,
    required this.residenceId,
    required this.newAttachments,
    required this.removedAttachments,
  });
}

/// Skriv eller redigera en egen motion. [onSave] returnerar ett felmeddelande
/// (som visas i arket) eller null; vid lyckad sparning stängs arket med `true`.
class MotionSheet extends CompositionWidget {
  const MotionSheet({
    super.key,
    this.motion,
    this.residences = const [],
    required this.onSave,
  });

  final Motion? motion;

  /// Bostäder där den inloggade bor. Med fler än en väljer medlemmen.
  final List<ResidencesRecord> residences;
  final Future<String?> Function(MotionInput input) onSave;

  static const _maxAttachments = 5;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final existing = props.value.motion;

    final (titleController, title, _) = useTextEditingController(
      text: existing?.title ?? '',
    );
    final (textController, text, _) = useTextEditingController(
      text: existing?.text ?? '',
    );
    final attachments = ref<List<PlatformFile>>([]);
    final removed = ref<List<String>>([]);
    final kept = computed(
      () => [
        for (final f in props.value.motion?.attachments ?? const <String>[])
          if (!removed.value.contains(f)) f,
      ],
    );
    final residenceIds = props.value.residences.map((r) => r.id).toList();
    final residenceId = ref(
      existing != null && residenceIds.contains(existing.residence)
          ? existing.residence
          : existing != null && existing.residence.isEmpty
          ? ''
          : (residenceIds.isEmpty ? '' : residenceIds.first),
    );
    final saving = ref(false);
    final error = ref<String?>(null);

    final canSaveDraft = computed(
      () => title.value.trim().isNotEmpty && !saving.value,
    );
    final canSubmit = computed(
      () =>
          title.value.trim().isNotEmpty &&
          text.value.trim().isNotEmpty &&
          !saving.value,
    );

    Future<void> pickFiles() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final room = MotionSheet._maxAttachments - kept.value.length;
      attachments.value = [
        ...attachments.value,
        ...result.files.where((f) => f.bytes != null),
      ].take(room < 0 ? 0 : room).toList();
    }

    Future<void> save(bool submit) async {
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        MotionInput(
          title: title.value.trim(),
          text: text.value.trim(),
          submit: submit,
          residenceId: residenceId.value,
          newAttachments: attachments.value,
          removedAttachments: removed.value,
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

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          existing == null ? 'Ny motion' : 'Redigera motion',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'En motion är ett förslag som stämman ska besluta om. Styrelsen '
          'yttrar sig över den innan stämman.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Rubrik',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textController,
          minLines: 5,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Bakgrund och förslag till beslut',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (props.value.residences.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: residenceId.value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bostad (valfritt)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Ingen bostad')),
              for (final r in props.value.residences)
                DropdownMenuItem(
                  value: r.id,
                  child: Text(r.streetAddress, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => residenceId.value = v ?? '',
          ),
          const SizedBox(height: 12),
        ],
        for (final f in kept.value)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(parseFilename(f).icon),
            title: Text(
              parseFilename(f).name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Ta bort bilagan',
              onPressed: saving.value
                  ? null
                  : () => removed.value = [...removed.value, f],
            ),
          ),
        for (final f in attachments.value)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Ta bort',
              onPressed: () => attachments.value = [
                for (final a in attachments.value)
                  if (a != f) a,
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                saving.value ||
                    kept.value.length + attachments.value.length >=
                        MotionSheet._maxAttachments
                ? null
                : pickFiles,
            icon: const Icon(Icons.attach_file),
            label: const Text('Bifoga fil'),
          ),
        ),
        if (error.value != null) ...[
          const SizedBox(height: 8),
          Text(error.value!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canSaveDraft.value ? () => save(false) : null,
                child: const Text('Spara utkast'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canSubmit.value ? () => save(true) : null,
                child: saving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lämna in'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'När motionen är inlämnad kan den inte längre ändras.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
