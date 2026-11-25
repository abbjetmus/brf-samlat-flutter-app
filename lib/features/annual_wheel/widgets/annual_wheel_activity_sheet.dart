import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/models/pocketbase_models.dart';
import '../annual_wheel_store.dart';

/// What the sheet returns on "Spara".
class AnnualWheelActivityInput {
  final String title;
  final String description;
  final int month;
  final int day;
  final String category;
  final String? responsible;
  final int reminderDaysBefore;
  final String recurrence;

  const AnnualWheelActivityInput({
    required this.title,
    required this.description,
    required this.month,
    required this.day,
    required this.category,
    required this.responsible,
    required this.reminderDaysBefore,
    required this.recurrence,
  });
}

const _reminderOptions = <(int, String)>[
  (0, 'Ingen påminnelse'),
  (3, '3 dagar innan'),
  (7, '1 vecka innan'),
  (14, '2 veckor innan'),
  (30, '1 månad innan'),
];

/// Create / edit an årshjul activity. Pops an [AnnualWheelActivityInput].
class AnnualWheelActivitySheet extends CompositionWidget {
  final AnnualWheelActivitiesRecord? activity;
  final int defaultMonth;
  final List<UsersRecord> users;

  const AnnualWheelActivitySheet({
    super.key,
    this.activity,
    required this.defaultMonth,
    required this.users,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final a = props.value.activity;

    final (titleController, title, _) = useTextEditingController(
      text: a?.title ?? '',
    );
    final (descriptionController, description, _) = useTextEditingController(
      text: a?.description ?? '',
    );
    final (dayController, day, _) = useTextEditingController(
      text: (a?.day ?? 0) > 0 ? '${a!.day}' : '',
    );
    final month = ref<int>(a?.month ?? props.value.defaultMonth);
    final category = ref<String>(a?.category ?? 'board');
    final responsible = ref<String?>(a?.responsible);
    final reminder = ref<int>(a?.reminderDaysBefore ?? 14);
    final recurrence = ref<String>(a?.recurrence ?? 'yearly');

    // "i januari, april, juli och oktober" for the hint under the month.
    final monthsLabel = computed(() {
      final months = occurrenceMonths(month.value, recurrence.value);
      if (months.length == 12) return 'varje månad';
      final names = [for (final m in months) monthNames[m - 1].toLowerCase()];
      return 'i ${names.sublist(0, names.length - 1).join(', ')} och ${names.last}';
    });

    final canSave = computed(() => title.value.trim().isNotEmpty);

    return (context) {
      final reminderValues = _reminderOptions.map((o) => o.$1).toSet();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              a == null ? 'Ny aktivitet' : 'Redigera aktivitet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Beskrivning',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: recurrence.value,
              decoration: const InputDecoration(
                labelText: 'Återkommer',
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in annualWheelRecurrences)
                  DropdownMenuItem(value: r.value, child: Text(r.title)),
              ],
              onChanged: (v) => recurrence.value = v ?? recurrence.value,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: month.value,
                    decoration: InputDecoration(
                      labelText: isRecurring(recurrence.value)
                          ? 'Första månaden'
                          : 'Månad',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(monthNames[m - 1]),
                        ),
                    ],
                    onChanged: (v) => month.value = v ?? month.value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Dag (valfri)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (isRecurring(recurrence.value)) ...[
              const SizedBox(height: 6),
              Text(
                'Infaller ${monthsLabel.value}. Varje tillfälle bockas av för sig.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.value.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category.value,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in annualWheelCategories)
                  DropdownMenuItem(value: c.value, child: Text(c.title)),
              ],
              onChanged: (v) => category.value = v ?? category.value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: responsible.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ansvarig (valfri)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ingen'),
                ),
                for (final u in props.value.users)
                  DropdownMenuItem<String?>(
                    value: u.id,
                    child: Text(
                      u.name.isNotEmpty ? u.name : (u.email ?? u.id),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => responsible.value = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: reminderValues.contains(reminder.value)
                  ? reminder.value
                  : 14,
              decoration: const InputDecoration(
                labelText: 'Påminnelse',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (value, label) in _reminderOptions)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (v) => reminder.value = v ?? reminder.value,
            ),
            const SizedBox(height: 8),
            Text(
              'Påminnelsen går via e-post och push till den ansvariga, eller till '
              'alla som får redigera årshjulet om ingen är ansvarig. En '
              'återkommande aktivitet påminns inför varje tillfälle.',
              style: TextStyle(
                fontSize: 12,
                color: theme.value.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSave.value
                  ? () => Navigator.of(context).pop(
                      AnnualWheelActivityInput(
                        title: title.value.trim(),
                        description: description.value.trim(),
                        month: month.value,
                        day: (int.tryParse(day.value) ?? 0).clamp(0, 31),
                        category: category.value,
                        responsible: responsible.value,
                        reminderDaysBefore: reminder.value,
                        recurrence: recurrence.value,
                      ),
                    )
                  : null,
              child: const Text('Spara'),
            ),
          ],
        ),
      );
    };
  }
}
