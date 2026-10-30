import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'motion_sheet.dart';

/// Egna motioner (även utkast) och andras inlämnade motioner med styrelsens
/// svar. Egna utkast kan redigeras och raderas. Styrelsen ([canManage]) skriver
/// yttrande och förslag till beslut, och med delete-behörighet kan den ta bort
/// inlämnade motioner.
class MotionsTab extends CompositionWidget {
  const MotionsTab({
    super.key,
    required this.meeting,
    this.canManage = false,
    this.locked = false,
    this.onAgendaChanged,
  });

  final GeneralMeeting meeting;
  final bool canManage;
  final bool locked;

  /// Ett svar med förslag lägger motionen på dagordningen.
  final Future<void> Function()? onAgendaChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final motions = ref<List<Motion>>([]);
    final residences = ref<List<ResidencesRecord>>([]);

    final windowHint = computed(() {
      final m = props.value.meeting;
      if (m.canSubmitMotions) {
        final deadline = formatMeetingDate(m.motionDeadline);
        return deadline.isEmpty
            ? 'Styrelsen tar emot motioner.'
            : 'Motioner tas emot till och med $deadline.';
      }
      if (m.status != GeneralMeetingStatus.draft &&
          m.status != GeneralMeetingStatus.called) {
        return 'Stämman har börjat — det går inte längre att lämna motioner.';
      }
      if (!m.motionsOpen) return 'Styrelsen tar inte emot motioner just nu.';
      return 'Sista dag för motioner har passerat.';
    });

    Future<void> load() async {
      final results = await Future.wait([
        store.getMotions(props.value.meeting.id),
        store.myResidences(),
      ]);
      motions.value = results[0] as List<Motion>;
      residences.value = results[1] as List<ResidencesRecord>;
      loading.value = false;
    }

    onMounted(load);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> openEditor([Motion? motion]) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => MotionSheet(
          motion: motion,
          residences: residences.value,
          onSave: (input) async {
            try {
              await store.saveMotion(
                motionId: motion?.id,
                meetingId: props.value.meeting.id,
                title: input.title,
                text: input.text,
                submit: input.submit,
                residenceId: input.residenceId,
                newAttachments: input.newAttachments,
                removedAttachments: input.removedAttachments,
              );
              return null;
            } catch (e) {
              return generalMeetingErrorMessage(e, 'Kunde inte spara motionen');
            }
          },
        ),
      );
      if (saved == true) {
        snack('Motionen är sparad');
        await load();
      }
    }

    Future<void> openAnswer(Motion motion) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final recommendation = await showAppBottomSheet<String>(
        context: ctx,
        builder: (_) => _AnswerSheet(
          motion: motion,
          onSave: (response, recommendation) async {
            try {
              await store.answerMotion(
                motion.id,
                boardResponse: response,
                recommendation: recommendation,
              );
              return null;
            } catch (e) {
              return generalMeetingErrorMessage(
                e,
                'Kunde inte spara yttrandet',
              );
            }
          },
        ),
      );
      if (recommendation == null) return;
      snack(
        recommendation.isNotEmpty
            ? 'Motionen är besvarad och finns på dagordningen'
            : 'Yttrandet är sparat',
      );
      await load();
      await props.value.onAgendaChanged?.call();
    }

    Future<void> deleteMotion(Motion motion) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final own = motion.submittedBy == store.currentUserId && motion.isDraft;
      final ok = await showConfirmDialog(
        ctx,
        title: own ? 'Radera utkast' : 'Ta bort motion',
        message: own
            ? 'Vill du radera utkastet "${motion.title}"?'
            : 'Vill du ta bort motionen ”${motion.title}”?',
        okLabel: own ? 'Radera' : 'Ta bort',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteMotion(motion.id);
        snack(own ? 'Utkastet är raderat' : 'Motionen är borttagen');
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte ta bort motionen'));
      }
    }

    void openAttachment(Motion motion, String filename) {
      final url = store.fileUrl(motion.collectionId, motion.id, filename);
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    void showDetails(Motion motion) {
      final ctx = contextRef.value;
      if (ctx == null) return;
      showAppBottomSheet<void>(
        context: ctx,
        builder: (_) => _MotionDetails(
          motion: motion,
          onOpenAttachment: (f) => openAttachment(motion, f),
        ),
      );
    }

    List<EntityAction> actionsFor(Motion motion) {
      final m = props.value.meeting;
      final mine = motion.submittedBy == store.currentUserId;
      if (mine && motion.isDraft) {
        return [
          if (m.canSubmitMotions)
            EntityAction.update(() => openEditor(motion)),
          EntityAction.delete(() => deleteMotion(motion)),
        ];
      }
      if (motion.isDraft || props.value.locked) return const [];
      return [
        if (props.value.canManage)
          EntityAction(
            icon: Icons.reply_outlined,
            label: motion.status == 'besvarad' ? 'Ändra yttrande' : 'Svara',
            onSelected: () => openAnswer(motion),
          ),
        if (store.canDelete)
          EntityAction.delete(() => deleteMotion(motion), label: 'Ta bort'),
      ];
    }

    return (context) {
      final m = props.value.meeting;
      final myId = store.currentUserId;
      final list = motions.value;

      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (props.value.canManage)
              const HelpTip(
                id: 'general-meeting-motions-board',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Inlämnade motioner syns här direkt; medlemmarna ser '
                    'varandras motioner när kallelsen är skickad. Tryck på ⋮ '
                    'och Svara för att skriva styrelsens yttrande och föreslå '
                    'bifall, avslag eller delvis bifall — då blir motionen en '
                    'beslutspunkt på dagordningen.',
              )
            else
              const HelpTip(
                id: 'general-meeting-motions',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'En motion är ett förslag som du vill att stämman beslutar '
                    'om. Spara gärna ett utkast först — ingen annan ser det. '
                    'Lämna in motionen före sista dag för motioner; styrelsen '
                    'svarar sedan med ett yttrande.',
              ),
            Text(windowHint.value, style: TextStyle(color: Colors.grey[600])),
            if (m.canSubmitMotions) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openEditor(),
                icon: const Icon(Icons.edit_note),
                label: const Text('Skriv motion'),
              ),
            ],
            const SizedBox(height: 16),
            if (loading.value)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Inga motioner än.', textAlign: TextAlign.center),
              )
            else
              for (final motion in list)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => showDetails(motion),
                    title: Text(
                      motion.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(
                            label: motion.statusLabel,
                            tone: switch (motion.status) {
                              'utkast' => StatusTone.neutral,
                              'besvarad' => StatusTone.success,
                              _ => StatusTone.info,
                            },
                          ),
                          Text(
                            [
                              motion.submittedBy == myId
                                  ? 'Din motion'
                                  : motion.submittedByName,
                              if (motion.residenceLabel.isNotEmpty)
                                motion.residenceLabel,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: actionsFor(motion).isEmpty
                        ? const Icon(Icons.chevron_right)
                        : EntityActionMenu(actions: actionsFor(motion)),
                  ),
                ),
          ],
        ),
      );
    };
  }
}

/// Styrelsens yttrande och förslag till beslut. Stänger med förslaget ('' =
/// inget förslag) när det är sparat.
class _AnswerSheet extends CompositionWidget {
  const _AnswerSheet({required this.motion, required this.onSave});

  final Motion motion;
  final Future<String?> Function(String response, String recommendation)
  onSave;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final (responseController, response, _) = useTextEditingController(
      text: props.value.motion.boardResponse,
    );
    final recommendation = ref(props.value.motion.recommendation);
    final saving = ref(false);
    final error = ref<String?>(null);

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        response.value.trim(),
        recommendation.value,
      );
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop(recommendation.value);
      }
    }

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Styrelsens yttrande',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          props.value.motion.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: responseController,
          minLines: 4,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Yttrande',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: recommendation.value,
          decoration: const InputDecoration(
            labelText: 'Styrelsen föreslår',
            helperText:
                'När du väljer ett förslag blir motionen besvarad och läggs '
                'till som beslutspunkt på dagordningen.',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Inget förslag än')),
            for (final (value, label) in motionRecommendations)
              DropdownMenuItem(value: value, child: Text(label)),
          ],
          onChanged: (v) => recommendation.value = v ?? '',
        ),
        if (error.value != null) ...[
          const SizedBox(height: 8),
          Text(error.value!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving.value ? null : save,
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

class _MotionDetails extends StatelessWidget {
  const _MotionDetails({required this.motion, required this.onOpenAttachment});

  final Motion motion;
  final ValueChanged<String> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          motion.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (motion.submittedByName.isNotEmpty)
          Text(
            [
              'Av ${motion.submittedByName}',
              if (motion.residenceLabel.isNotEmpty) motion.residenceLabel,
            ].join(' · '),
            style: TextStyle(color: Colors.grey[600]),
          ),
        const SizedBox(height: 12),
        Text(motion.text.isEmpty ? '—' : motion.text),
        for (final f in motion.attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(parseFilename(f).icon),
            title: Text(parseFilename(f).name),
            onTap: () => onOpenAttachment(f),
          ),
        if (motion.boardResponse.isNotEmpty ||
            motion.recommendationLabel.isNotEmpty) ...[
          const Divider(height: 32),
          Text(
            'Styrelsens yttrande',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (motion.boardResponse.isNotEmpty) Text(motion.boardResponse),
          if (motion.recommendationLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${motion.recommendationLabel}.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ],
    );
  }
}
