import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'motion_sheet.dart';

/// Egna motioner (även utkast) och andras inlämnade motioner med styrelsens
/// svar. Egna utkast kan redigeras och raderas.
class MotionsTab extends CompositionWidget {
  const MotionsTab({super.key, required this.meeting});

  final GeneralMeeting meeting;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final motions = ref<List<Motion>>([]);

    final windowHint = computed(() {
      final m = props.value.meeting;
      if (m.canSubmitMotions) {
        final deadline = formatMeetingDate(m.motionDeadline);
        return deadline.isEmpty
            ? 'Styrelsen tar emot motioner.'
            : 'Motioner tas emot till och med $deadline.';
      }
      if (!m.motionsOpen) return 'Styrelsen tar inte emot motioner just nu.';
      return 'Sista dag för motioner har passerat.';
    });

    Future<void> load() async {
      motions.value = await store.getMotions(props.value.meeting.id);
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
          onSave: (input) async {
            try {
              await store.saveMotion(
                motionId: motion?.id,
                meetingId: props.value.meeting.id,
                title: input.title,
                text: input.text,
                submit: input.submit,
                newAttachments: input.newAttachments,
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

    Future<void> deleteMotion(Motion motion) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera utkast',
        message: 'Vill du radera utkastet "${motion.title}"?',
        okLabel: 'Radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteMotion(motion.id);
        snack('Utkastet är raderat');
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte radera utkastet'));
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
                            motion.submittedBy == myId
                                ? 'Din motion'
                                : motion.submittedByName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: motion.submittedBy == myId && motion.isDraft
                        ? EntityActionMenu(
                            actions: [
                              if (m.canSubmitMotions)
                                EntityAction.update(() => openEditor(motion)),
                              EntityAction.delete(() => deleteMotion(motion)),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                  ),
                ),
          ],
        ),
      );
    };
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
            'Av ${motion.submittedByName}',
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
