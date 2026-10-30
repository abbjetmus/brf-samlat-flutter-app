import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../maintenance_plan_store.dart';

double _parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

String _numberText(double value) => value <= 0
    ? ''
    : (value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString().replaceAll('.', ','));

/// "Ny åtgärd i underhållsplanen" / "Redigera åtgärd". Saves through [onSave]
/// and closes itself (pops `true`) on success; errors are shown in the sheet.
class MaintenanceItemSheet extends CompositionWidget {
  final MaintenancePlanItemsRecord? item;
  final int defaultYear;
  final Future<String?> Function(MaintenancePlanItemInput input) onSave;

  const MaintenanceItemSheet({
    super.key,
    this.item,
    required this.defaultYear,
    required this.onSave,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final item = props.value.item;
    final contextRef = useContext();

    final (titleController, title, _) = useTextEditingController(
      text: item?.title ?? '',
    );
    final (yearController, year, _) = useTextEditingController(
      text: '${item?.plannedYear ?? props.value.defaultYear}',
    );
    final (intervalController, interval, _) = useTextEditingController(
      text: (item?.intervalYears ?? 0) > 0 ? '${item!.intervalYears}' : '0',
    );
    final (estimatedController, estimated, _) = useTextEditingController(
      text: _numberText(item?.estimatedCost ?? 0),
    );
    final (actualController, actual, _) = useTextEditingController(
      text: _numberText(item?.actualCost ?? 0),
    );
    final (descriptionController, description, _) = useTextEditingController(
      text: item?.description ?? '',
    );
    final component = ref<String>(item?.component ?? 'tak');
    final status = ref<String>(item?.status ?? 'planerad');
    final saving = ref(false);
    final error = ref<String?>(null);

    final yearValue = computed(() => int.tryParse(year.value.trim()));
    final yearValid = computed(() {
      final y = yearValue.value;
      return y != null && y >= 1900 && y <= 2200;
    });
    final canSave = computed(
      () => !saving.value && title.value.trim().isNotEmpty && yearValid.value,
    );

    Future<void> save() async {
      if (!canSave.value) return;
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        MaintenancePlanItemInput(
          title: title.value.trim(),
          component: component.value,
          status: status.value,
          plannedYear: yearValue.value!,
          intervalYears: (int.tryParse(interval.value.trim()) ?? 0).clamp(
            0,
            100,
          ),
          estimatedCost: _parseNumber(estimated.value).clamp(0, double.infinity),
          actualCost: _parseNumber(actual.value).clamp(0, double.infinity),
          description: description.value.trim(),
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

    final digits = [FilteringTextInputFormatter.digitsOnly];
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9,. ]'))];

    return (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item == null ? 'Ny åtgärd i underhållsplanen' : 'Redigera åtgärd',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Åtgärd',
              hintText: 't.ex. Omläggning av tak',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: component.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Byggnadsdel',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in maintenanceComponents)
                      DropdownMenuItem(value: c.value, child: Text(c.title)),
                  ],
                  onChanged: (v) => component.value = v ?? component.value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in maintenanceStatusLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => status.value = v ?? status.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: InputDecoration(
                    labelText: 'Planerat år',
                    border: const OutlineInputBorder(),
                    errorText: yearValid.value ? null : 'Ange ett år',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Återkommer vart X år',
                    helperText: '0 = engångsåtgärd',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: estimatedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: money,
                  decoration: const InputDecoration(
                    labelText: 'Beräknad kostnad',
                    suffixText: 'kr',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: actualController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: money,
                  decoration: const InputDecoration(
                    labelText: 'Verklig kostnad',
                    suffixText: 'kr',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Beskrivning',
              border: OutlineInputBorder(),
            ),
          ),
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave.value ? save : null,
            child: saving.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Spara'),
          ),
        ],
      );
    };
  }
}
