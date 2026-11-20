import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';

/// Skapa styrelsemöte, eller redigera ett befintligt med [meetingId]
/// (`/board/create?id=<id>`, samma som webbens
/// `/portal/board/create-meeting?id=…`). Detaljsidan visar bara "Redigera"
/// så länge ingen har signerat protokollet.
class CreateBoardMeetingPage extends CompositionWidget {
  static const String path = '/board/create';

  /// Sätts för att redigera ett befintligt möte.
  final String? meetingId;

  const CreateBoardMeetingPage({super.key, this.meetingId});

  static String editPath(String meetingId) =>
      '$path?id=${Uri.encodeQueryComponent(meetingId)}';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final boardStore = inject(boardStoreKey);
    final editId = props.value.meetingId;
    final isEdit = editId != null && editId.isNotEmpty;
    final (streetAddressController, streetAddress, _) =
        useTextEditingController();
    final (zipCodeController, zipCode, _) = useTextEditingController();
    final (localityController, locality, _) = useTextEditingController();
    final startDate = ref<DateTime?>(null);
    final endDate = ref<DateTime?>(null);
    // The chosen meeting template ("Mötesmall"): its id is stored as the
    // meeting's `meeting_protocol_id` and its `meeting_protocol` JSON is copied
    // onto the meeting (a required field server-side).
    final selectedTemplate = ref<BoardMeetingTemplatesRecord?>(null);
    final templates = boardStore.templates;
    final addToCalendar = ref(false);
    final loading = ref(false);
    final contextRef = useContext();
    final theme = useTheme();
    // Redigering: mötet som läses in, och om det är inläst än.
    final editing = ref<BoardMeetingsRecord?>(null);
    final prefilled = ref(!isEdit);

    // Load the available templates once when the page opens.
    onMounted(() async {
      if (!isEdit) {
        await boardStore.getTemplates();
        return;
      }
      await Future.wait([
        boardStore.getTemplates(),
        boardStore.getBoardMeeting(editId),
      ]);
      final meeting = boardStore.currentMeeting.value;
      if (meeting == null || meeting.id != editId) {
        prefilled.value = true;
        return;
      }
      editing.value = meeting;
      startDate.value = DateTime.tryParse(meeting.startAt)?.toLocal();
      endDate.value = DateTime.tryParse(meeting.endAt)?.toLocal();
      streetAddress.value = meeting.streetAddress;
      zipCode.value = meeting.zipCode;
      locality.value = meeting.locality;
      addToCalendar.value = meeting.addToCalendar;
      for (final t in templates.value) {
        if (t.id == meeting.meetingProtocolId) selectedTemplate.value = t;
      }
      prefilled.value = true;
    });

    Future<void> pickDateTime(
      BuildContext context,
      Ref<DateTime?> target,
    ) async {
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

      target.value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    String formatPickedDateTime(DateTime? dt) {
      if (dt == null) return 'Välj datum & tid';
      final d =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final t =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d $t';
    }

    Future<void> createMeeting() async {
      if (startDate.value == null || endDate.value == null) return;
      if (streetAddressController.text.trim().isEmpty) return;
      if (zipCodeController.text.trim().isEmpty) return;
      if (localityController.text.trim().isEmpty) return;
      final template = selectedTemplate.value;
      final current = editing.value;

      if (isEdit) {
        if (current == null) return;
        // Ny mall ersätter protokollets punkter (som i webben); samma mall
        // (eller en mall som inte längre finns) lämnar protokollet orört.
        final templateChanged =
            template != null && template.id != current.meetingProtocolId;
        loading.value = true;
        final success = await boardStore.updateBoardMeeting(
          id: current.id,
          startAt: startDate.value!.toUtc().toIso8601String(),
          endAt: endDate.value!.toUtc().toIso8601String(),
          streetAddress: streetAddressController.text.trim(),
          zipCode: zipCodeController.text.trim(),
          locality: localityController.text.trim(),
          meetingProtocolId: template?.id ?? current.meetingProtocolId,
          meetingProtocol: templateChanged
              ? (template.meetingProtocol ?? const [])
              : null,
          addToCalendar: addToCalendar.value,
        );
        loading.value = false;

        final context = contextRef.value;
        if (context != null && context.mounted) {
          if (success) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Styrelsemötet har uppdaterats.'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Kunde inte uppdatera styrelsemötet.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
        return;
      }

      if (template == null) return;

      loading.value = true;
      final success = await boardStore.createBoardMeeting(
        startAt: startDate.value!.toUtc().toIso8601String(),
        endAt: endDate.value!.toUtc().toIso8601String(),
        streetAddress: streetAddressController.text.trim(),
        zipCode: zipCodeController.text.trim(),
        locality: localityController.text.trim(),
        meetingProtocolId: template.id,
        meetingProtocol: template.meetingProtocol ?? const [],
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
            SnackBar(
              content: const Text('Kunde inte skapa styrelsemöte.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera styrelsemöte' : 'Skapa styrelsemöte',
      body: !prefilled.value
          ? const Center(child: CircularProgressIndicator())
          : isEdit && editing.value == null
          ? const Center(child: Text('Styrelsemötet hittades inte.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isEdit)
                    const HelpTip(
                      id: 'board-meeting-create',
                      padding: EdgeInsets.only(bottom: 12),
                      text:
                          'Ange tid och plats och välj en mötesmall. Mallens punkter '
                          'blir mötets protokoll.',
                    ),
                  // Start date/time
                  Text(
                    'Starttid',
                    style: TextStyle(
                      color: theme.value.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pickDateTime(context, startDate),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(formatPickedDateTime(startDate.value)),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // End date/time
                  Text(
                    'Sluttid',
                    style: TextStyle(
                      color: theme.value.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pickDateTime(context, endDate),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(formatPickedDateTime(endDate.value)),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
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

                  // Meeting template — supplies the required meeting protocol.
                  DropdownButtonFormField<BoardMeetingTemplatesRecord>(
                    // initialValue läses bara när fältet skapas; nyckeln bygger om
                    // det när mallarna (och vid redigering mötet) har lästs in.
                    key: ValueKey(
                      'template-${templates.value.length}-${prefilled.value}',
                    ),
                    initialValue: selectedTemplate.value,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(
                          labelText: 'Mötesmall',
                          border: OutlineInputBorder(),
                        ).copyWith(
                          helperText: isEdit
                              ? 'Byter du mall ersätts protokollets punkter när du '
                                    'sparar — det som redan skrivits försvinner.'
                              : null,
                          helperMaxLines: 3,
                        ),
                    hint: Text(
                      templates.value.isEmpty
                          ? 'Inga mallar tillgängliga'
                          : 'Välj mötesmall',
                    ),
                    items: [
                      for (final t in templates.value)
                        DropdownMenuItem(value: t, child: Text(t.name)),
                    ],
                    onChanged: (t) => selectedTemplate.value = t,
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Lägg till i kalender'),
                    subtitle: const Text(
                      'Mötet visas som "Styrelsemöte" med tid och adress i föreningens kalender, i appen och på webben, för alla medlemmar.',
                    ),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEdit ? 'Spara ändringar' : 'Skapa styrelsemöte',
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
