import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_keys.dart';
import '../general_meetings_models.dart';

/// Skapa eller redigera en stämma (styrelsen). Stänger med den sparade stämman.
/// Mirrors the web `generalMeeting/FormDialog.vue`.
class MeetingFormSheet extends CompositionWidget {
  const MeetingFormSheet({super.key, this.meeting});

  /// null = ny stämma.
  final GeneralMeeting? meeting;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();
    final existing = props.value.meeting;

    final type = ref(
      existing?.type.isNotEmpty == true ? existing!.type : 'ordinarie',
    );
    final startAt = ref<DateTime?>(
      existing == null ? null : parsePbDate(existing.startAt),
    );
    final deadline = ref<DateTime?>(
      existing == null ? null : parsePbDate(existing.motionDeadline),
    );
    final digital = ref(existing?.digital ?? false);
    final motionsOpen = ref(existing?.motionsOpen ?? false);
    final voteMode = ref(existing?.voteMode ?? 'per_residence');
    final saving = ref(false);
    final error = ref<String?>(null);

    final (titleController, title, _) = useTextEditingController(
      text: existing?.title ?? '',
    );
    final (locationController, location, _) = useTextEditingController(
      text: existing?.location ?? '',
    );
    final (digitalInfoController, digitalInfo, _) = useTextEditingController(
      text: existing?.digitalInfo ?? '',
    );
    final (descriptionController, description, _) = useTextEditingController(
      text: existing?.description ?? '',
    );

    // Röstläget kan bara väljas innan kallelsen har skickats.
    final canChooseVoteMode =
        existing == null || existing.status == GeneralMeetingStatus.draft;

    void suggestTitle() {
      final year = (startAt.value ?? DateTime.now()).year;
      final current = title.value;
      if (current.isEmpty ||
          meetingTypeLabels.values.any((l) => current.startsWith(l))) {
        title.value = '${meetingTypeLabels[type.value]} $year';
      }
    }

    onMounted(() async {
      if (existing != null) return;
      suggestTitle();
      try {
        final settings = await store.getSettings();
        voteMode.value = settings.voteMode;
      } catch (_) {
        // Standardvärdet (per bostad) gäller; servern sätter annars sitt.
      }
    });

    Future<DateTime?> pickDateTime(DateTime? initial) async {
      final ctx = contextRef.value;
      if (ctx == null) return null;
      final now = DateTime.now();
      final date = await showDatePicker(
        context: ctx,
        initialDate: initial ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
      );
      if (date == null || !ctx.mounted) return null;
      final time = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.fromDateTime(
          initial ?? DateTime(now.year, now.month, now.day, 18),
        ),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    final canSave = computed(
      () =>
          title.value.trim().isNotEmpty &&
          startAt.value != null &&
          !saving.value,
    );

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      final body = <String, dynamic>{
        'title': title.value.trim(),
        'type': type.value,
        'start_at': toPbDate(startAt.value),
        'location': location.value.trim(),
        'digital': digital.value,
        'digital_info': digital.value ? digitalInfo.value.trim() : '',
        'description': description.value,
        'motions_open': motionsOpen.value,
        'motion_deadline': toPbDate(deadline.value),
        if (canChooseVoteMode) 'vote_mode': voteMode.value,
      };
      try {
        final saved = existing == null
            ? await store.createMeeting(body)
            : await store.updateMeeting(existing.id, body);
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(saved);
      } catch (e) {
        error.value = generalMeetingErrorMessage(e, 'Kunde inte spara stämman');
      } finally {
        saving.value = false;
      }
    }

    final dateFormat = DateFormat("d MMM yyyy 'kl.' HH.mm", 'sv_SE');

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          existing == null ? 'Ny föreningsstämma' : 'Redigera stämma',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: type.value,
          decoration: const InputDecoration(
            labelText: 'Typ av stämma',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in meetingTypeLabels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v == null) return;
            type.value = v;
            suggestTitle();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Rubrik',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _DateField(
          label: 'Datum och tid',
          value: startAt.value == null ? '' : dateFormat.format(startAt.value!),
          onTap: () async {
            final picked = await pickDateTime(startAt.value);
            if (picked == null) return;
            startAt.value = picked;
            suggestTitle();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: locationController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Plats',
            hintText: 'T.ex. Föreningslokalen, Storgatan 1',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Digitalt deltagande'),
          value: digital.value,
          onChanged: (v) => digital.value = v,
        ),
        if (digital.value) ...[
          TextField(
            controller: digitalInfoController,
            decoration: const InputDecoration(
              labelText: 'Länk eller instruktioner för digitalt deltagande',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            legalNote,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Text i kallelsen (valfritt)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Divider(height: 32),
        const Text('Motioner', style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ta emot motioner'),
          value: motionsOpen.value,
          onChanged: (v) => motionsOpen.value = v,
        ),
        Text(
          'När du tar emot motioner ser medlemmarna stämmans rubrik, datum och '
          'sista dag för motioner redan innan kallelsen är skickad. '
          'Dagordningen visas först med kallelsen.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        _DateField(
          label: 'Sista dag för motioner',
          value: deadline.value == null
              ? ''
              : dateFormat.format(deadline.value!),
          enabled: motionsOpen.value,
          onTap: () async {
            final picked = await pickDateTime(deadline.value);
            if (picked != null) deadline.value = picked;
          },
          onClear: deadline.value == null ? null : () => deadline.value = null,
        ),
        if (canChooseVoteMode) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('vote-mode-${voteMode.value}'),
            initialValue: voteMode.value,
            decoration: const InputDecoration(
              labelText: 'Röstning på den här stämman',
              helperText: 'Låses när kallelsen skickas.',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'per_residence',
                child: Text('En röst per bostad'),
              ),
              DropdownMenuItem(
                value: 'per_member',
                child: Text('En röst per medlem'),
              ),
            ],
            onChanged: (v) => voteMode.value = v ?? voteMode.value,
          ),
        ],
        if (error.value != null) ...[
          const SizedBox(height: 12),
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
              : const Text('Spara'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          border: const OutlineInputBorder(),
          suffixIcon: onClear != null && enabled
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Rensa',
                  onPressed: onClear,
                )
              : const Icon(Icons.event),
        ),
        child: Text(value),
      ),
    );
  }
}
