import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import '../widgets/general_meeting_status_chip.dart';
import '../widgets/meeting_form_sheet.dart';
import '../widgets/settings_sheet.dart';
import 'general_meeting_detail_page.dart';

/// Föreningens stämmor — senaste datum först. Styrelsen (general_meetings +
/// update) ser även utkasten, skapar nya stämmor och ändrar föreningens
/// stämmoinställningar.
class GeneralMeetingsListPage extends CompositionWidget {
  static const String path = '/general-meetings';

  const GeneralMeetingsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();
    final canManage = computed(() => store.canManage);

    onMounted(() {
      store.getMeetings();
    });

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> open(GeneralMeeting meeting) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      await ctx.push('${GeneralMeetingDetailPage.path}/${meeting.id}');
      // Styrelsen kan ha ändrat eller raderat stämman.
      if (canManage.value) await store.getMeetings();
    }

    Future<void> create() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<GeneralMeeting>(
        context: ctx,
        builder: (_) => const MeetingFormSheet(),
      );
      if (saved == null) return;
      snack('Stämman är skapad');
      await store.getMeetings();
      await open(saved);
    }

    Future<void> openSettings() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => const GeneralMeetingSettingsSheet(),
      );
      if (saved == true) snack('Inställningarna är sparade');
    }

    return (context) {
      final meetings = store.meetings.value;
      final loading = store.listLoading.value;
      final manage = canManage.value;

      final Widget list;
      if (loading && meetings.isEmpty) {
        list = const Center(child: CircularProgressIndicator());
      } else if (meetings.isEmpty) {
        list = RefreshIndicator(
          onRefresh: store.getMeetings,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.gavel_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  manage
                      ? 'Inga stämmor än. Skapa föreningens ordinarie stämma '
                            'eller en extra stämma. Den är ett utkast tills du '
                            'skickar kallelsen.'
                      : 'Ingen stämma är utlyst än. När styrelsen kallar till '
                            'stämma eller tar emot motioner syns den här.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      } else {
        list = PaginatedListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
          itemCount: meetings.length,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.fetchNextMeetings,
          onRefresh: store.getMeetings,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            final upcoming = meeting.isUpcoming;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  Icons.gavel_outlined,
                  color: upcoming ? null : Colors.grey,
                ),
                title: Text(
                  meeting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          formatMeetingDateTime(meeting.startAt),
                          if (meeting.location.isNotEmpty) meeting.location,
                        ].join(' · '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          GeneralMeetingStatusChip(
                            meeting: meeting,
                            board: manage,
                          ),
                          if (manage &&
                              meeting.status == GeneralMeetingStatus.draft &&
                              meeting.motionsOpen)
                            const StatusChip(
                              label: 'Tar emot motioner',
                              tone: StatusTone.info,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(meeting),
              ),
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Föreningsstämma',
        subtitle: manage
            ? 'Kallelse, motioner, fullmakter, omröstning och protokoll'
            : null,
        actions: [
          if (manage)
            HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Inställningar',
              onPressed: openSettings,
            ),
        ],
        floatingActionButton: manage
            ? FloatingActionButton.extended(
                onPressed: create,
                icon: const Icon(Icons.add),
                label: const Text('Ny stämma'),
              )
            : null,
        body: Column(
          children: [
            if (manage)
              const HelpTip(
                id: 'general-meetings',
                text:
                    'Skapa stämman som ett utkast, lägg till dagordningen och '
                    'skicka kallelsen när allt är klart. Alla medlemmar får då '
                    'e-post och en notis, och stämman hamnar i kalendern. Under '
                    'Inställningar (kugghjulet) anger du om föreningen röstar '
                    'per bostad eller per medlem och vilken kallelsetid '
                    'stadgarna kräver.',
              )
            else
              const HelpTip(
                id: 'general-meetings-member',
                text:
                    'Här ser du föreningens stämmor. Tryck på en stämma för att '
                    'läsa dagordningen, lämna en motion, ge en fullmakt, rösta '
                    'och läsa det justerade protokollet.',
              ),
            Expanded(child: list),
          ],
        ),
      );
    };
  }
}
