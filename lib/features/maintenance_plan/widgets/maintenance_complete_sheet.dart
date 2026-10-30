import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import '../maintenance_plan_store.dart';

typedef CompleteCallback =
    Future<String?> Function({
      required DateTime completedAt,
      double? actualCost,
      required bool createNext,
      int? nextYear,
    });

/// "Markera som klar": date, actual cost and, for a recurring action, the next
/// occurrence (counted from when the action was actually done). Mirrors the
/// web's MaintenancePlanCompleteDialog. Pops `true` on success.
class MaintenanceCompleteSheet extends CompositionWidget {
  final MaintenancePlanItemsRecord item;

  /// Whether the user may create items; otherwise no next occurrence.
  final bool canCreate;
  final CompleteCallback onComplete;

  const MaintenanceCompleteSheet({
    super.key,
    required this.item,
    required this.canCreate,
    required this.onComplete,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final item = props.value.item;
    final contextRef = useContext();
    final recurring = item.intervalYears > 0;

    final initialCost = item.actualCost > 0
        ? item.actualCost
        : item.estimatedCost;
    final (costController, cost, _) = useTextEditingController(
      text: initialCost > 0 ? initialCost.toStringAsFixed(0) : '',
    );
    final (nextYearController, nextYear, _) = useTextEditingController(
      text: '${DateTime.now().year + item.intervalYears}',
    );
    final completedAt = ref<DateTime>(DateTime.now());
    final createNext = ref<bool>(props.value.canCreate);
    final saving = ref(false);
    final error = ref<String?>(null);

    // The next occurrence follows from when the action was actually done.
    watch(() => completedAt.value, (date, _) {
      if (recurring) nextYear.value = '${date.year + item.intervalYears}';
    });

    Future<void> pickDate() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: completedAt.value,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (picked != null) completedAt.value = picked;
    }

    Future<void> submit() async {
      saving.value = true;
      error.value = null;
      final costText = cost.value.trim().replaceAll(' ', '').replaceAll(',', '.');
      final message = await props.value.onComplete(
        completedAt: completedAt.value,
        actualCost: costText.isEmpty ? null : double.tryParse(costText),
        createNext: recurring && createNext.value,
        nextYear: int.tryParse(nextYear.value.trim()),
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Markera som klar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.title} (${item.plannedYear})',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Klar datum',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              child: Text(DateFormat('yyyy-MM-dd').format(completedAt.value)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,. ]')),
            ],
            decoration: InputDecoration(
              labelText: 'Verklig kostnad',
              suffixText: 'kr',
              helperText: 'Beräknat: ${formatSek(item.estimatedCost)}',
              border: const OutlineInputBorder(),
            ),
          ),
          if (recurring) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: createNext.value,
              onChanged: props.value.canCreate
                  ? (v) => createNext.value = v ?? false
                  : null,
              title: Text(
                'Skapa nästa tillfälle (återkommer vart ${item.intervalYears} år)',
              ),
            ),
            if (createNext.value)
              TextField(
                controller: nextYearController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Planerat år för nästa tillfälle',
                  border: OutlineInputBorder(),
                ),
              ),
            if (!props.value.canCreate)
              Text(
                'Du saknar behörighet att skapa nya poster, så nästa tillfälle '
                'får läggas till av någon annan.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: saving.value ? null : submit,
            icon: saving.value
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Markera som klar'),
          ),
        ],
      );
    };
  }
}
