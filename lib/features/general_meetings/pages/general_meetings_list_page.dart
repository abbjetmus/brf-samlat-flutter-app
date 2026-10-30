import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../general_meetings_models.dart';
import '../widgets/general_meeting_status_chip.dart';
import 'general_meeting_detail_page.dart';

/// Föreningens stämmor — kommande först (sorterade på datum, senaste först).
class GeneralMeetingsListPage extends CompositionWidget {
  static const String path = '/general-meetings';

  const GeneralMeetingsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(generalMeetingsStoreKey);

    onMounted(() {
      store.getMeetings();
    });

    return (context) {
      final meetings = store.meetings.value;
      final loading = store.listLoading.value;

      return GradientScaffold(
        title: 'Föreningsstämma',
        body: loading && meetings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : meetings.isEmpty
            ? RefreshIndicator(
                onRefresh: store.getMeetings,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.gavel_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Ingen stämma är utlyst än. När styrelsen kallar till '
                        'stämma eller tar emot motioner syns den här.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            : PaginatedListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                              formatMeetingDateTime(meeting.startAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GeneralMeetingStatusChip(meeting: meeting),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${GeneralMeetingDetailPage.path}/${meeting.id}',
                      ),
                    ),
                  );
                },
              ),
      );
    };
  }
}
