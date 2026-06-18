import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import 'board_meeting_detail_page.dart';
import 'create_board_meeting_page.dart';

class BoardMeetingsListPage extends CompositionWidget {
  static const String path = '/board';

  const BoardMeetingsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final boardStore = inject(boardStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      boardStore.getAllBoardMeetings();
    });

    return (context) {
      final meetings = boardStore.boardMeetings.value;
      final loading = boardStore.listLoading.value;
      final loadingMore = boardStore.loadingMore.value;
      final hasMore = boardStore.hasMore.value;
      final canCreate = authStore.hasPermission(
        'board_meetings',
        CrudOperation.create,
      );

      return GradientScaffold(
        title: 'Styrelsemöten',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreateBoardMeetingPage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && meetings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : meetings.isEmpty
            ? const Center(child: Text('Inga styrelsemöten ännu.'))
            : PaginatedListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: meetings.length,
                hasMore: hasMore,
                loadingMore: loadingMore,
                onLoadMore: boardStore.fetchNextBoardMeetings,
                onRefresh: boardStore.getAllBoardMeetings,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final meeting = meetings[index];
                  final dateStr = AppDateUtils.formatDateLong(meeting.startAt);
                  final timeStr = AppDateUtils.formatTime(meeting.startAt);
                  final address =
                      '${meeting.streetAddress}, ${meeting.zipCode} ${meeting.locality}';

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        Icons.groups_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(
                        dateStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kl. $timeStr',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${BoardMeetingDetailPage.path}/${meeting.id}',
                      ),
                    ),
                  );
                },
              ),
      );
    };
  }
}
