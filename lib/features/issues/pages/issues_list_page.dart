import 'package:flutter/material.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
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
      // A member with a residence may report for it (residence_issues) as well
      // as for the whole association (issues); CreateIssuePage offers the kinds
      // that are allowed.
      final canCreate =
          authStore.hasPermission('issues', CrudOperation.create) ||
          (authStore.residence.value != null &&
              authStore.hasPermission(
                'residence_issues',
                CrudOperation.create,
              ));

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
        title: 'Ärenden',
        actions: [
          FilterChip(
            label: Text(showResolved ? 'Alla' : 'Öppna'),
            selected: showResolved,
            onSelected: (_) => issuesStore.toggleShowResolved(),
          ),
        ],
        floatingActionButton: canCreate
            ? FloatingActionButton(
                tooltip: 'Ny felanmälan',
                onPressed: () => context.push(CreateIssuePage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            const HelpTip(
              id: 'issues-list',
              text:
                  'Här samlas föreningens felanmälningar och ärenden. Tryck på '
                  'ett ärende för att se detaljer, bilagor och kommentarer. '
                  'Ärenden med husikon gäller en viss bostad.',
            ),
            Expanded(
              child: loading && issues.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : issues.isEmpty
            ? const Center(child: Text('Inga felanmälningar eller ärenden.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: SearchField(
                      hintText: 'Sök ärende',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredIssues.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                            itemCount: filteredIssues.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: issuesStore.fetchNextIssues,
                            onRefresh: issuesStore.getAllIssues,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final issue = filteredIssues[index];
                              return _IssueCard(
                                issue: issue,
                                onTap: () => context.push(
                                  '${IssueDetailPage.path}/${issue.id}',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    };
  }
}

class _IssueCard extends StatelessWidget {
  final IssuesViewRecord issue;
  final VoidCallback onTap;

  const _IssueCard({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meta = theme.textTheme.bodySmall;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        (issue.type ?? 'Felanmälan').toUpperCase(),
                        AppDateUtils.friendlyDay(issue.created).toUpperCase(),
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  if ((issue.residence ?? '').isNotEmpty) ...[
                    Tooltip(
                      message: 'Gäller en bostad',
                      child: Icon(
                        Icons.home_outlined,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  StatusChip(
                    label: issue.isResolved ? 'Löst' : 'Öppen',
                    tone: issue.isResolved
                        ? StatusTone.success
                        : StatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                issue.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
              ),
              if (issue.commentCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      issue.commentCount == 1
                          ? '1 kommentar'
                          : '${issue.commentCount} kommentarer',
                      style: meta,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
