import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import 'issue_detail_page.dart';
import 'create_issue_page.dart';

class IssuesListPage extends CompositionWidget {
  static const String path = '/issues';

  const IssuesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      issuesStore.getAllIssues();
    });

    return (context) {
      final issues = issuesStore.issuesList.value;
      final loading = issuesStore.listLoading.value;
      final loadingMore = issuesStore.loadingMore.value;
      final hasMore = issuesStore.hasMore.value;
      final showResolved = issuesStore.showResolved.value;
      final canCreate = authStore.hasPermission('issues', CrudOperation.create);

      final query = searchQuery.value.trim().toLowerCase();
      final filteredIssues = query.isEmpty
          ? issues
          : issues
                .where(
                  (i) =>
                      i.title.toLowerCase().contains(query) ||
                      i.description.toLowerCase().contains(query),
                )
                .toList();

      return GradientScaffold(
        title: 'Felanmälan & ärenden',
        actions: [
          FilterChip(
            label: Text(showResolved ? 'Alla' : 'Öppna'),
            selected: showResolved,
            onSelected: (_) => issuesStore.toggleShowResolved(),
          ),
        ],
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchField(
                      hintText: 'Sök ärende...',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredIssues.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredIssues.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: issuesStore.fetchNextIssues,
                            onRefresh: issuesStore.getAllIssues,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final issue = filteredIssues[index];
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final isErrand =
                                  (issue.type ?? 'Felanmälan') == 'Ärende';
                              final typeSwatch = isErrand
                                  ? Colors.blue
                                  : Colors.orange;
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: Icon(
                                    issue.isResolved
                                        ? Icons.check_circle
                                        : Icons.report_problem_outlined,
                                    color: issue.isResolved
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  title: Text(
                                    issue.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: typeSwatch.withValues(
                                            alpha: isDark ? 0.25 : 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          issue.type ?? 'Felanmälan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? typeSwatch.shade200
                                                : typeSwatch.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppDateUtils.timeAgo(issue.created),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (issue.commentCount > 0) ...[
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.comment_outlined,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${issue.commentCount}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                    '${IssueDetailPage.path}/${issue.id}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      );
    };
  }
}
