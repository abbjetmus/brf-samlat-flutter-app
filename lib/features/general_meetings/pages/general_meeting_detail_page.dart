import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../general_meetings_models.dart';
import '../widgets/agenda_tab.dart';
import '../widgets/motions_tab.dart';
import '../widgets/overview_tab.dart';
import '../widgets/protocol_tab.dart';
import '../widgets/proxy_tab.dart';
import '../widgets/voting_tab.dart';

/// En stämma för medlemmen: översikt, dagordning, motioner, fullmakt,
/// omröstning och protokoll. Öppnas från listan, kalendern eller en push
/// (`/app/general-meetings/<id>`).
class GeneralMeetingDetailPage extends CompositionWidget {
  static const String path = '/general-meetings';

  final String meetingId;

  const GeneralMeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);

    final loading = ref(true);
    final meeting = ref<GeneralMeeting?>(null);
    final items = ref<List<GeneralMeetingItem>>([]);

    Future<void> load() async {
      final id = props.value.meetingId;
      final results = await Future.wait([
        store.getMeeting(id),
        store.getItems(id),
      ]);
      meeting.value = results[0] as GeneralMeeting?;
      items.value = results[1] as List<GeneralMeetingItem>;
    }

    onMounted(() async {
      await load();
      loading.value = false;
    });

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

      return DefaultTabController(
        length: 6,
        child: GradientScaffold(
          title: m.title,
          subtitle: m.typeLabel,
          body: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Översikt'),
                  Tab(text: 'Dagordning'),
                  Tab(text: 'Motioner'),
                  Tab(text: 'Fullmakt'),
                  Tab(text: 'Omröstning'),
                  Tab(text: 'Protokoll'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    OverviewTab(
                      meeting: m,
                      itemCount: items.value.length,
                      onRefresh: load,
                    ),
                    AgendaTab(meeting: m, items: items.value, onRefresh: load),
                    MotionsTab(meeting: m),
                    ProxyTab(meeting: m),
                    VotingTab(meeting: m),
                    ProtocolTab(meeting: m),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}
