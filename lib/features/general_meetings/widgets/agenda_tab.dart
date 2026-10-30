import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'general_meeting_status_chip.dart';

/// Typisk dagordning för en ordinarie stämma i en bostadsrättsförening
/// (samma som webben).
const _standardAgenda = <(String, bool)>[
  ('Stämmans öppnande', false),
  ('Val av stämmoordförande', true),
  ('Anmälan av stämmoordförandens val av protokollförare', false),
  ('Godkännande av röstlängd', true),
  ('Fastställande av dagordning', true),
  ('Val av två justerare tillika rösträknare', true),
  ('Fråga om stämman blivit stadgeenligt kallad', true),
  ('Genomgång av styrelsens årsredovisning', false),
  ('Genomgång av revisorns berättelse', false),
  ('Beslut om fastställande av resultat- och balansräkning', true),
  ('Beslut om resultatdisposition', true),
  ('Fråga om ansvarsfrihet för styrelsens ledamöter', true),
  ('Fråga om arvoden åt styrelseledamöter och revisorer', true),
  ('Val av styrelseledamöter och suppleanter', true),
  ('Val av revisorer', true),
  ('Val av valberedning', true),
  ('Av styrelsen till stämman hänskjutna frågor samt motioner', false),
  ('Stämmans avslutande', false),
];

/// Dagordningen. Publiceras med kallelsen. Styrelsen ([canManage]) lägger till,
/// redigerar, flyttar och tar bort punkter så länge protokollet inte är
/// justerat ([locked]).
class AgendaTab extends CompositionWidget {
  const AgendaTab({
    super.key,
    required this.meeting,
    required this.items,
    required this.onRefresh,
    this.canManage = false,
    this.locked = false,
  });

  final GeneralMeeting meeting;
  final List<GeneralMeetingItem> items;
  final Future<void> Function() onRefresh;
  final bool canManage;
  final bool locked;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();
    final busy = ref(false);

    final editable = computed(
      () => props.value.canManage && !props.value.locked,
    );

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> openEditor([GeneralMeetingItem? item]) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => _ItemSheet(
          item: item,
          onSave: (title, description, isDecision) async {
            try {
              final body = {
                'title': title,
                'description': description,
                'is_decision': isDecision,
              };
              if (item == null) {
                final items = props.value.items;
                await store.createItem({
                  ...body,
                  'general_meeting': props.value.meeting.id,
                  'sort_order': (items.isEmpty ? 0 : items.last.sortOrder) + 1,
                });
              } else {
                await store.updateItem(item.id, body);
              }
              return null;
            } catch (e) {
              return generalMeetingErrorMessage(e, 'Kunde inte spara punkten');
            }
          },
        ),
      );
      if (saved == true) await props.value.onRefresh();
    }

    Future<void> seedStandard() async {
      busy.value = true;
      try {
        for (final (i, (title, isDecision)) in _standardAgenda.indexed) {
          await store.createItem({
            'general_meeting': props.value.meeting.id,
            'sort_order': i + 1,
            'title': title,
            'description': '',
            'is_decision': isDecision,
          });
        }
      } catch (e) {
        snack(
          generalMeetingErrorMessage(e, 'Kunde inte lägga till dagordningen'),
        );
      } finally {
        busy.value = false;
        await props.value.onRefresh();
      }
    }

    // Byt plats med grannen och numrera om, så att ordningen alltid är 1..n.
    Future<void> move(int index, int delta) async {
      final items = [...props.value.items];
      final target = index + delta;
      if (target < 0 || target >= items.length) return;
      final moved = items.removeAt(index);
      items.insert(target, moved);
      busy.value = true;
      try {
        await Future.wait([
          for (final (i, item) in items.indexed)
            if (item.sortOrder != i + 1)
              store.updateItem(item.id, {'sort_order': i + 1}),
        ]);
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte flytta punkten'));
      } finally {
        busy.value = false;
        await props.value.onRefresh();
      }
    }

    Future<void> remove(GeneralMeetingItem item) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Ta bort punkt',
        message:
            'Vill du ta bort ”${item.title}” från dagordningen? Eventuella '
            'röster tas också bort.',
        okLabel: 'Ta bort',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteItem(item.id);
        await props.value.onRefresh();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte ta bort punkten'));
      }
    }

    return (context) {
      final meeting = props.value.meeting;
      final items = props.value.items;
      final canEdit = editable.value;

      return RefreshIndicator(
        onRefresh: props.value.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (props.value.canManage)
              const HelpTip(
                id: 'general-meeting-agenda',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Dagordningen skickas med kallelsen. Markera de punkter som '
                    'stämman fattar beslut om som beslutspunkt — de går att '
                    'rösta om under Omröstning. En besvarad motion läggs till '
                    'här automatiskt.',
              ),
            if (canEdit) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} punkter',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  if (busy.value)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: busy.value ? null : () => openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Lägg till punkt'),
                  ),
                ],
              ),
              if (items.isEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: busy.value ? null : seedStandard,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Standarddagordning'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Text(
                  props.value.canManage
                      ? 'Ingen dagordning än. Lägg till punkter eller börja med '
                            'en standarddagordning för en ordinarie stämma.'
                      : meeting.status == GeneralMeetingStatus.draft
                      ? 'Dagordningen publiceras med kallelsen.'
                      : 'Dagordningen är tom.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final (i, item) in items.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, canEdit ? 4 : 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '§ ${i + 1}  ${item.title}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (item.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.description.trim()),
                            ],
                            if (item.isDecision || item.motion.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (item.isDecision)
                                    VoteStatusChip(voteStatus: item.voteStatus),
                                  if (item.motion.isNotEmpty)
                                    const StatusChip(
                                      label: 'Motion',
                                      icon: Icons.lightbulb_outline,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canEdit)
                        EntityActionMenu(
                          actions: [
                            EntityAction.update(
                              () => openEditor(item),
                              label: 'Redigera',
                            ),
                            if (i > 0)
                              EntityAction(
                                icon: Icons.arrow_upward,
                                label: 'Flytta upp',
                                onSelected: () => move(i, -1),
                              ),
                            if (i < items.length - 1)
                              EntityAction(
                                icon: Icons.arrow_downward,
                                label: 'Flytta ner',
                                onSelected: () => move(i, 1),
                              ),
                            EntityAction.delete(
                              () => remove(item),
                              label: 'Ta bort',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    };
  }
}

/// Ny eller redigerad punkt. [onSave] returnerar ett felmeddelande eller null;
/// vid lyckad sparning stängs arket med `true`.
class _ItemSheet extends CompositionWidget {
  const _ItemSheet({this.item, required this.onSave});

  final GeneralMeetingItem? item;
  final Future<String?> Function(
    String title,
    String description,
    bool isDecision,
  )
  onSave;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final existing = props.value.item;

    final (titleController, title, _) = useTextEditingController(
      text: existing?.title ?? '',
    );
    final (descriptionController, description, _) = useTextEditingController(
      text: existing?.description ?? '',
    );
    final isDecision = ref(existing?.isDecision ?? false);
    final saving = ref(false);
    final error = ref<String?>(null);

    final canSave = computed(
      () => title.value.trim().isNotEmpty && !saving.value,
    );

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        title.value.trim(),
        description.value,
        isDecision.value,
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
          existing == null ? 'Ny punkt' : 'Redigera punkt',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          autofocus: existing == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Rubrik',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          minLines: 3,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Beskrivning / förslag till beslut',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Beslutspunkt (röstning)'),
          value: isDecision.value,
          // En punkt med påbörjad omröstning måste förbli en beslutspunkt.
          onChanged: existing?.voteStarted == true
              ? null
              : (v) => isDecision.value = v,
        ),
        if (error.value != null) ...[
          const SizedBox(height: 8),
          Text(error.value!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
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
