import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import 'issue_detail_page.dart';
import 'create_issue_page.dart';

class IssuesListPage extends CompositionWidget {
  static const String path = '/issues';

  const IssuesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      issuesStore.getAllIssues();
    });

    return (context) {
      final issues = issuesStore.issuesList.value;
      final loading = issuesStore.loading.value;
      final showResolved = issuesStore.showResolved.value;
      final canCreate = authStore.hasPermission('issues', CrudOperation.create);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Felanmälan & ärenden'),
          actions: [
            FilterChip(
              label: Text(showResolved ? 'Alla' : 'Öppna'),
              selected: showResolved,
              onSelected: (_) => issuesStore.toggleShowResolved(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreateIssuePage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && issues.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : issues.isEmpty
                ? const Center(child: Text('Inga felanmälningar eller ärenden.'))
                : RefreshIndicator(
                    onRefresh: () => issuesStore.getAllIssues(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: Icon(
                              issue.isResolved
                                  ? Icons.check_circle
                                  : Icons.report_problem_outlined,
                              color: issue.isResolved ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              issue.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: ((issue.type ?? 'Felanmälan') == 'Ärende'
                                            ? Colors.blue
                                            : Colors.orange)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    issue.type ?? 'Felanmälan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (issue.type ?? 'Felanmälan') == 'Ärende'
                                          ? Colors.blue.shade800
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppDateUtils.timeAgo(issue.created),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                if (issue.commentCount > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.comment_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${issue.commentCount}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('${IssueDetailPage.path}/${issue.id}'),
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
