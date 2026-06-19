import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/comments_list.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'create_issue_page.dart';

class IssueDetailPage extends CompositionWidget {
  static const String path = '/issues/detail';

  final String issueId;

  const IssueDetailPage({super.key, required this.issueId});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      issuesStore.getIssue(issueId);
      issuesStore.getComments(issueId);
    });

    return (context) {
      final issue = issuesStore.currentIssue.value;
      final comments = issuesStore.comments.value;
      final loading = issuesStore.loading.value;
      final currentUserId = authStore.currentUser.value?.id;
      final canEdit = authStore.hasPermission('issues', CrudOperation.update);
      final canDelete = authStore.hasPermission('issues', CrudOperation.delete);

      if (loading && issue == null) {
        return const GradientScaffold(
          title: 'Felanmälan & ärenden',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (issue == null) {
        return const GradientScaffold(
          title: 'Felanmälan & ärenden',
          body: Center(child: Text('Hittades inte.')),
        );
      }

      return GradientScaffold(
        title: issue.type ?? 'Felanmälan',
        actions: [
          if (canEdit || canDelete)
            EntityActionMenu.header(
              actions: [
                if (canEdit)
                  EntityAction.update(() {
                    context.push('${CreateIssuePage.editPath}/${issue.id}');
                  }),
                if (canEdit)
                  EntityAction(
                    icon: issue.isResolved
                        ? Icons.refresh
                        : Icons.check_circle_outline,
                    label: issue.isResolved ? 'Återöppna' : 'Markera som löst',
                    onSelected: () async {
                      if (issue.isResolved) {
                        await issuesStore.unresolveIssue(issue.id);
                      } else {
                        await issuesStore.resolveIssue(issue.id);
                      }
                    },
                  ),
                if (canDelete)
                  EntityAction.delete(() async {
                    final noun = (issue.type ?? 'Felanmälan').toLowerCase();
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Radera $noun',
                      message: 'Är du säker på att du vill radera denna $noun?',
                      okLabel: 'Radera',
                      okColor: Colors.red,
                    );
                    if (confirmed) {
                      await issuesStore.deleteIssue(issue.id);
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
              // Issue header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type + status chips
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(issue.type ?? 'Felanmälan'),
                          backgroundColor:
                              (issue.type ?? 'Felanmälan') == 'Ärende'
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                        ),
                        Chip(
                          avatar: Icon(
                            issue.isResolved
                                ? Icons.check_circle
                                : Icons.report_problem,
                            size: 16,
                            color: issue.isResolved
                                ? Colors.green
                                : Colors.orange,
                          ),
                          label: Text(issue.isResolved ? 'Löst' : 'Öppen'),
                          backgroundColor: issue.isResolved
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issue.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppDateUtils.formatDateLong(issue.created),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (issue.consentToMasterKey == true) ...[
                      const SizedBox(height: 8),
                      Chip(
                        avatar: const Icon(Icons.key, size: 16),
                        label: const Text('Samtycke till huvudnyckel'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1),

              // Issue body
              Padding(
                padding: const EdgeInsets.all(16),
                child: RichDescription(html: issue.description),
              ),

              // Resolved info
              if (issue.isResolved && issue.resolvedAt != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Löst: ${AppDateUtils.formatDateTime(issue.resolvedAt)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],

              // Comments section
              if (issue.commentsAllowed) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16),
                  child: Text(
                    'Kommentarer (${comments.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CommentsList(
                  comments: comments.map((c) {
                    final expandUser = c.expand?['user'];
                    String? userName;
                    if (expandUser is Map<String, dynamic>) {
                      userName = expandUser['name'] as String?;
                    } else if (expandUser is List && expandUser.isNotEmpty) {
                      userName =
                          (expandUser.first as Map<String, dynamic>)['name']
                              as String?;
                    }
                    return CommentItem(
                      id: c.id,
                      comment: c.comment,
                      created: c.created,
                      userId: c.user,
                      userName: userName,
                    );
                  }).toList(),
                  currentUserId: currentUserId,
                  onAddComment: (comment) =>
                      issuesStore.addComment(issueId, comment),
                  onEditComment: canEdit
                      ? (id, comment) =>
                            issuesStore.updateComment(id, comment, issueId)
                      : null,
                  onDeleteComment: canDelete
                      ? (id) => issuesStore.deleteComment(id, issueId)
                      : null,
                ),
              ],
            ],
          ),
        ),
      );
    };
  }
}
