import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';

class CreateBoardMeetingPage extends CompositionWidget {
  static const String path = '/board/create';

  const CreateBoardMeetingPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final boardStore = inject(boardStoreKey);
    final (streetAddressController, _, __) = useTextEditingController();
    final (zipCodeController, a1, a2) = useTextEditingController();
    final (localityController, a3, a4) = useTextEditingController();
    final (protocolIdController, a5, a6) = useTextEditingController();
    final startDate = ref<DateTime?>(null);
    final endDate = ref<DateTime?>(null);
    final addToCalendar = ref(false);
    final loading = ref(false);
    final contextRef = useContext();

    Future<void> pickDateTime(BuildContext context, Ref<DateTime?> target) async {
      final date = await showDatePicker(
        context: context,
        initialDate: target.value ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        locale: const Locale('sv', 'SE'),
      );
      if (date == null) return;

      if (!context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(target.value ?? DateTime.now()),
      );
      if (time == null) return;

      target.value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    String formatPickedDateTime(DateTime? dt) {
      if (dt == null) return 'Välj datum & tid';
      final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d $t';
    }

    Future<void> createMeeting() async {
      if (startDate.value == null || endDate.value == null) return;
      if (streetAddressController.text.trim().isEmpty) return;
      if (zipCodeController.text.trim().isEmpty) return;
      if (localityController.text.trim().isEmpty) return;
      if (protocolIdController.text.trim().isEmpty) return;

      loading.value = true;
      final success = await boardStore.createBoardMeeting(
        startAt: startDate.value!.toUtc().toIso8601String(),
        endAt: endDate.value!.toUtc().toIso8601String(),
        streetAddress: streetAddressController.text.trim(),
        zipCode: zipCodeController.text.trim(),
        locality: localityController.text.trim(),
        meetingProtocolId: protocolIdController.text.trim(),
        addToCalendar: addToCalendar.value,
      );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Styrelsemöte skapat!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunde inte skapa styrelsemöte.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Skapa styrelsemöte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Start date/time
            Text('Starttid', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => pickDateTime(context, startDate),
              icon: const Icon(Icons.calendar_month),
              label: Text(formatPickedDateTime(startDate.value)),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // End date/time
            Text('Sluttid', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => pickDateTime(context, endDate),
              icon: const Icon(Icons.calendar_month),
              label: Text(formatPickedDateTime(endDate.value)),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Street address
            TextFormField(
              controller: streetAddressController,
              decoration: const InputDecoration(
                labelText: 'Gatuadress',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Zip code
            TextFormField(
              controller: zipCodeController,
              decoration: const InputDecoration(
                labelText: 'Postnummer',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Locality
            TextFormField(
              controller: localityController,
              decoration: const InputDecoration(
                labelText: 'Ort',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Meeting protocol ID
            TextFormField(
              controller: protocolIdController,
              decoration: const InputDecoration(
                labelText: 'Protokoll-ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Lägg till i kalender'),
              value: addToCalendar.value,
              onChanged: (v) => addToCalendar.value = v,
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: loading.value ? null : createMeeting,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Skapa styrelsemöte'),
            ),
          ],
        ),
      ),
    );
  }
}
