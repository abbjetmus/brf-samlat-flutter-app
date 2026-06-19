import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_description.dart';

class BoardMeetingDetailPage extends CompositionWidget {
  static const String path = '/board/detail';

  final String meetingId;

  const BoardMeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget Function(BuildContext) setup() {
    final boardStore = inject(boardStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      boardStore.getBoardMeeting(meetingId);
    });

    return (context) {
      final meeting = boardStore.currentMeeting.value;
      final loading = boardStore.loading.value;
      final canDelete = authStore.hasPermission(
        'board_meetings',
        CrudOperation.delete,
      );

      if (loading && meeting == null) {
        return const GradientScaffold(
          title: 'Styrelsemöte',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (meeting == null) {
        return const GradientScaffold(
          title: 'Styrelsemöte',
          body: Center(child: Text('Styrelsemöte hittades inte.')),
        );
      }

      final dateStr = AppDateUtils.formatDateLong(meeting.startAt);
      final startTime = AppDateUtils.formatTime(meeting.startAt);
      final endTime = AppDateUtils.formatTime(meeting.endAt);
      final address =
          '${meeting.streetAddress}, ${meeting.zipCode} ${meeting.locality}';

      return GradientScaffold(
        title: 'Styrelsemöte',
        actions: [
          if (canDelete)
            EntityActionMenu.header(
              actions: [
                EntityAction.delete(() async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera styrelsemöte',
                    message:
                        'Är du säker på att du vill radera detta styrelsemöte?',
                    okLabel: 'Radera',
                    okColor: Colors.red,
                  );
                  if (confirmed) {
                    await boardStore.deleteBoardMeeting(meeting.id);
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  }
                }),
              ],
            ),
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Time
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$startTime - $endTime',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Address
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Meeting Protocol ID
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protokoll-ID',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            meeting.meetingProtocolId,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Meeting Agenda
              if (meeting.meetingAgenda != null &&
                  meeting.meetingAgenda!.isNotEmpty) ...[
                const Divider(height: 1),
                _MeetingItemsSection(
                  title: 'Dagordning',
                  items: meeting.meetingAgenda!,
                ),
              ],

              // Meeting Protocol
              if (meeting.meetingProtocol != null &&
                  meeting.meetingProtocol!.isNotEmpty) ...[
                const Divider(height: 1),
                _MeetingItemsSection(
                  title: 'Mötesprotokoll',
                  items: meeting.meetingProtocol!,
                ),
              ],
            ],
          ),
        ),
      );
    };
  }
}

/// Renders a meeting agenda/protocol section. Each entry is a template item
/// (`{question, hint, answer}` where `answer` is rich-text HTML); plain string
/// entries are supported for backwards compatibility.
class _MeetingItemsSection extends StatelessWidget {
  const _MeetingItemsSection({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;

            String question = '';
            String answer = '';
            if (item is Map) {
              question = (item['question'] as String?)?.trim() ?? '';
              answer = (item['answer'] as String?)?.trim() ?? '';
            } else {
              answer = '$item';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (question.isNotEmpty)
                    Text(
                      '$index. $question',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (answer.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: question.isNotEmpty ? 4 : 0,
                        left: question.isNotEmpty ? 16 : 0,
                      ),
                      child: RichDescription(html: answer, fontSize: 15),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
