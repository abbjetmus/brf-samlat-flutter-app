import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../general_meetings_models.dart';

/// Föreningens stämmoinställningar: rösträtt, kallelsetid och fullmakter.
/// Stänger med `true` när de är sparade. Mirrors the web `SettingsDialog.vue`.
class GeneralMeetingSettingsSheet extends CompositionWidget {
  const GeneralMeetingSettingsSheet({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final saving = ref(false);
    final error = ref<String?>(null);
    final voteMode = ref('per_residence');
    final (maxWeeksController, maxWeeks, _) = useTextEditingController(
      text: '6',
    );
    final (minWeeksController, minWeeks, _) = useTextEditingController(
      text: '2',
    );
    final (proxiesController, proxies, _) = useTextEditingController(
      text: '1',
    );

    onMounted(() async {
      try {
        final s = await store.getSettings();
        voteMode.value = s.voteMode;
        maxWeeks.value = '${s.noticeMaxWeeks}';
        minWeeks.value = '${s.noticeMinWeeks}';
        proxies.value = '${s.maxProxiesPerHolder}';
      } catch (e) {
        error.value = generalMeetingErrorMessage(
          e,
          'Kunde inte hämta inställningarna',
        );
      } finally {
        loading.value = false;
      }
    });

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      try {
        await store.saveSettings(
          GeneralMeetingSettings(
            voteMode: voteMode.value,
            noticeMinWeeks: int.tryParse(minWeeks.value.trim()) ?? 0,
            noticeMaxWeeks: int.tryParse(maxWeeks.value.trim()) ?? 0,
            maxProxiesPerHolder: int.tryParse(proxies.value.trim()) ?? 0,
          ),
        );
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
      } catch (e) {
        error.value = generalMeetingErrorMessage(
          e,
          'Kunde inte spara inställningarna',
        );
      } finally {
        saving.value = false;
      }
    }

    final caption = TextStyle(color: Colors.grey[600], fontSize: 12);

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Stämmoinställningar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ställ in det som föreningens stadgar säger om stämman. '
          'Inställningarna gäller nya stämmor; en stämma som redan är kallad '
          'behåller sitt röstläge.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (loading.value)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          const Text('Rösträtt', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<String>(
            groupValue: voteMode.value,
            onChanged: (v) => voteMode.value = v ?? voteMode.value,
            child: const Column(
              children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'per_residence',
                  title: Text('En röst per bostad'),
                  subtitle: Text(
                    'Vanligast: innehavare av samma bostadsrätt har '
                    'tillsammans en röst.',
                  ),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'per_member',
                  title: Text('En röst per medlem'),
                  subtitle: Text('Varje boende med konto har en egen röst.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kallelsetid',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: maxWeeksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tidigast (veckor före)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: minWeeksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Senast (veckor före)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Vanliga stadgar: tidigast sex och senast två veckor före stämman. '
            'Du får en varning om kallelsen skickas utanför perioden.',
            style: caption,
          ),
          const SizedBox(height: 16),
          const Text(
            'Fullmakter',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: proxiesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Antal fullmakter per ombud',
              helperText: '0 = ingen gräns. Många stadgar tillåter bara en.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (error.value != null) ...[
          const SizedBox(height: 12),
          Text(error.value!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading.value || saving.value ? null : save,
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
