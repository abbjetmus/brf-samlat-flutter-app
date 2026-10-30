import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import '../residence_applications_store.dart';

typedef DecisionCallback =
    Future<String?> Function({
      required String status,
      required String note,
      String? periodTo,
    });

/// "Fatta beslut": under behandling / bevilja / avslå with a note to the
/// applicant, and the approved end date for a sublet. Mirrors the decision
/// dialog in the web's residence-applications/[id].vue. Pops `true` on success.
class ApplicationDecisionSheet extends CompositionWidget {
  final ResidenceApplicationsRecord application;
  final DecisionCallback onSave;

  const ApplicationDecisionSheet({
    super.key,
    required this.application,
    required this.onSave,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final a = props.value.application;
    final contextRef = useContext();
    final day = DateFormat('yyyy-MM-dd');

    final status = ref<String>(a.status == 'inskickad' ? 'beviljad' : a.status);
    final (noteController, note, _) = useTextEditingController(
      text: a.decisionNote,
    );
    final periodFrom = DateTime.tryParse(a.periodFrom ?? '');
    final periodTo = ref<DateTime?>(DateTime.tryParse(a.periodTo ?? ''));
    final saving = ref(false);
    final error = ref<String?>(null);

    final approvesSublet = computed(
      () => a.type == 'andrahand' && status.value == 'beviljad',
    );
    final valid = computed(() {
      if (!approvesSublet.value) return true;
      final to = periodTo.value;
      if (to == null) return false;
      return periodFrom == null ||
          day.format(to).compareTo(day.format(periodFrom)) >= 0;
    });

    Future<void> pickEnd() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final first = periodFrom ?? DateTime(2000);
      final initial = periodTo.value ?? first;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: initial.isBefore(first) ? first : initial,
        firstDate: first,
        lastDate: DateTime(2100),
      );
      if (picked != null) periodTo.value = picked;
    }

    Future<void> save() async {
      if (!valid.value) return;
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        status: status.value,
        note: note.value.trim(),
        periodTo: approvesSublet.value && periodTo.value != null
            ? day.format(periodTo.value!)
            : null,
      );
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
    }

    const options = <(String, String, Color)>[
      ('under behandling', 'Under behandling', Colors.orange),
      ('beviljad', 'Bevilja', Colors.green),
      ('avslagen', 'Avslå', Colors.red),
    ];

    return (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fatta beslut',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: status.value,
            onChanged: (v) => status.value = v ?? status.value,
            child: Column(
              children: [
                for (final (value, label, color) in options)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    activeColor: color,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          if (approvesSublet.value) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: pickEnd,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Beviljas till och med',
                  helperText:
                      'Styrelsen påminns 30 dagar innan perioden tar slut',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  errorText: valid.value ? null : 'Välj ett slutdatum',
                ),
                child: Text(
                  periodTo.value == null ? '' : day.format(periodTo.value!),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Motivering / kommentar till den sökande',
              hintText: status.value == 'avslagen'
                  ? 'Ange skälet till avslaget'
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Den sökande får beskedet och kommentaren via push och e-post.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: valid.value && !saving.value ? save : null,
            child: saving.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Spara beslut'),
          ),
        ],
      );
    };
  }
}
