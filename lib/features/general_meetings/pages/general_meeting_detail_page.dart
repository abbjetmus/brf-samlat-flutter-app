import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../general_meetings_models.dart';
import '../widgets/agenda_tab.dart';
import '../widgets/meeting_form_sheet.dart';
import '../widgets/motions_tab.dart';
import '../widgets/overview_tab.dart';
import '../widgets/protocol_tab.dart';
import '../widgets/proxy_tab.dart';
import '../widgets/voters_tab.dart';
import '../widgets/voting_tab.dart';

/// En stämma: översikt, dagordning, motioner, fullmakt, omröstning och
/// protokoll. Styrelsen (general_meetings + update) leder stämman här och ser
/// även röstlängden. Öppnas från listan, kalendern eller en push
/// (`/app/general-meetings/<id>`).
class GeneralMeetingDetailPage extends CompositionWidget {
  static const String path = '/general-meetings';

  final String meetingId;

  const GeneralMeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final meeting = ref<GeneralMeeting?>(null);
    final items = ref<List<GeneralMeetingItem>>([]);
    // Justerat (minst en signatur): stämman kan inte längre ändras.
    final locked = ref(false);

    // Reaktiv: hasPermission läser authStore-refs, som laddas asynkront vid
    // kallstart.
    final canManage = computed(() => store.canManage);

    Future<void> loadLock() async {
      if (!canManage.value) return;
      try {
        final sigs = await store.getSignatures(props.value.meetingId);
        locked.value = sigs.isLocked;
      } catch (_) {
        // Ingen justering än — eller inte åtkomlig; låset kontrolleras ändå
        // av servern vid varje ändring.
      }
    }

    Future<void> load() async {
      final id = props.value.meetingId;
      final results = await Future.wait([
        store.getMeeting(id),
        store.getItems(id),
      ]);
      meeting.value = results[0] as GeneralMeeting?;
      items.value = results[1] as List<GeneralMeetingItem>;
    }

    Future<void> reloadItems() async {
      items.value = await store.getItems(props.value.meetingId);
    }

    onMounted(() async {
      await load();
      loading.value = false;
    });

    watch(() => canManage.value, (manage, _) {
      if (manage) loadLock();
    }, immediate: true);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> edit() async {
      final ctx = contextRef.value;
      final m = meeting.value;
      if (ctx == null || m == null) return;
      final saved = await showAppBottomSheet<GeneralMeeting>(
        context: ctx,
        builder: (_) => MeetingFormSheet(meeting: m),
      );
      if (saved != null) {
        meeting.value = saved;
        snack('Stämman är sparad');
      }
    }

    Future<void> delete() async {
      final ctx = contextRef.value;
      final m = meeting.value;
      if (ctx == null || m == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera stämma',
        message:
            'Stämman tas bort med dagordning, motioner, fullmakter, röster och '
            'protokoll. Detta kan inte ångras.',
        okLabel: 'Ja, radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteMeeting(m.id);
        snack('Stämman är raderad');
        store.getMeetings();
        final c = contextRef.value;
        if (c != null && c.mounted) Navigator.of(c).maybePop();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte radera stämman'));
      }
    }

    return (context) {
      if (loading.value) {
        return const GradientScaffold(
          title: 'Föreningsstämma',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final m = meeting.value;
      if (m == null) {
        return const GradientScaffold(
          title: 'Föreningsstämma',
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Stämman kunde inte hittas. Den kan ha tagits bort.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      final manage = canManage.value;
      final isLocked = locked.value;
      // Medlemmar ser bara Översikt och Motioner innan kallelsen (dagordningen
      // publiceras med kallelsen); röstlängden är styrelsens.
      final memberDraft = !manage && m.status == GeneralMeetingStatus.draft;
      final tabs = <(String, Widget)>[
        (
          'Översikt',
          OverviewTab(
            meeting: m,
            itemCount: items.value.length,
            onRefresh: load,
            canManage: manage,
            onEdit: !isLocked && m.status != GeneralMeetingStatus.closed
                ? edit
                : null,
          ),
        ),
        if (!memberDraft)
          (
            'Dagordning',
            AgendaTab(
              meeting: m,
              items: items.value,
              onRefresh: reloadItems,
              canManage: manage,
              locked: isLocked,
            ),
          ),
        (
          'Motioner',
          MotionsTab(
            meeting: m,
            canManage: manage,
            locked: isLocked,
            onAgendaChanged: reloadItems,
          ),
        ),
        if (manage) ('Röstlängd', VotersTab(meeting: m)),
        if (!memberDraft)
          (
            manage ? 'Fullmakter' : 'Fullmakt',
            ProxyTab(meeting: m, canManage: manage),
          ),
        if (!memberDraft)
          (
            'Omröstning',
            VotingTab(meeting: m, canManage: manage, locked: isLocked),
          ),
        if (!memberDraft)
          (
            'Protokoll',
            ProtocolTab(
              meeting: m,
              canManage: manage,
              onLockedChanged: (v) => locked.value = v,
            ),
          ),
      ];

      return DefaultTabController(
        key: ValueKey('tabs-${tabs.length}'),
        length: tabs.length,
        child: GradientScaffold(
          title: m.title,
          subtitle: m.typeLabel,
          actions: [
            if (manage)
              EntityActionMenu.header(
                actions: [
                  if (!isLocked && m.status != GeneralMeetingStatus.closed)
                    EntityAction.update(edit, label: 'Redigera stämma'),
                  EntityAction.delete(delete),
                ],
              ),
          ],
          body: Column(
            children: [
              if (isLocked)
                Container(
                  width: double.infinity,
                  color: Colors.blue.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Protokollet är justerat och stämman kan inte längre '
                          'ändras.',
                        ),
                      ),
                    ],
                  ),
                ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final (label, _) in tabs) Tab(text: label)],
              ),
              Expanded(
                child: TabBarView(
                  children: [for (final (_, child) in tabs) child],
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}
