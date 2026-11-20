import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import 'post_detail_page.dart';
import 'create_post_page.dart';

class PostsListPage extends CompositionWidget {
  static const String path = '/posts';

  const PostsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final postsStore = inject(postsStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      postsStore.getAllPosts();
    });

    return (context) {
      final posts = postsStore.postsList.value;
      final loading = postsStore.listLoading.value;
      final loadingMore = postsStore.loadingMore.value;
      final hasMore = postsStore.hasMore.value;
      final canCreate = authStore.hasPermission('posts', CrudOperation.create);

      final query = searchQuery.value.trim().toLowerCase();
      final filteredPosts = query.isEmpty
          ? posts
          : posts
                .where(
                  (p) =>
                      p.title.toLowerCase().contains(query) ||
                      p.description.toLowerCase().contains(query),
                )
                .toList();

      // Fästa inlägg ("Bra att veta") överst, sedan flödet per månad.
      final pinned = filteredPosts.where((p) => p.pinAsGeneralInfo).toList();
      final feed = filteredPosts.where((p) => !p.pinAsGeneralInfo).toList();
      final rows = <Widget Function(BuildContext)>[
        (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: SearchField(
            hintText: 'Sök bland anslag',
            onChanged: (v) => searchQuery.value = v,
          ),
        ),
        if (pinned.isNotEmpty)
          (context) => _PinnedStrip(
            posts: pinned,
            onTap: (p) => context.push('${PostDetailPage.path}/${p.id}'),
          ),
      ];
      String? lastMonth;
      for (final post in feed) {
        final month = _monthHeading(post.created);
        if (month != lastMonth) {
          lastMonth = month;
          rows.add((context) => _MonthHeading(month));
        }
        rows.add(
          (context) => _PostCard(
            post: post,
            onTap: () => context.push('${PostDetailPage.path}/${post.id}'),
          ),
        );
      }

      return GradientScaffold(
        title: 'Anslag',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                tooltip: 'Nytt anslag',
                onPressed: () => context.push(CreatePostPage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            HelpTip(
              id: 'posts-list',
              text: canCreate
                  ? 'Anslag är föreningens nyheter till medlemmarna. Tryck på '
                        '+ för att publicera ett och samtidigt skicka en '
                        'push-notis eller lägga det i kalendern.'
                  : 'Anslag är föreningens nyheter till medlemmarna. Tryck på '
                        'ett anslag för att läsa det och kommentera, om '
                        'kommentarer är påslagna.',
            ),
            Expanded(
              child: loading && posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : posts.isEmpty
                  ? const Center(child: Text('Inga anslag ännu.'))
                  : PaginatedListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: rows.length +
                          (query.isNotEmpty && filteredPosts.isEmpty ? 1 : 0),
                      hasMore: hasMore,
                      loadingMore: loadingMore,
                      onLoadMore: postsStore.fetchNextPosts,
                      onRefresh: postsStore.getAllPosts,
                      separatorBuilder: (_, _) => const SizedBox(height: 0),
                      itemBuilder: (context, index) => index < rows.length
                          ? rows[index](context)
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('Inga träffar.')),
                            ),
                    ),
            ),
          ],
        ),
      );
    };
  }
}

String _monthHeading(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  final month = AppDateUtils.formatMonth(iso);
  final cap = month.isEmpty ? month : month[0].toUpperCase() + month.substring(1);
  return date.year == DateTime.now().year ? cap : '$cap ${date.year}';
}

class _MonthHeading extends StatelessWidget {
  final String text;
  const _MonthHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 20, 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _PinnedStrip extends StatelessWidget {
  final List<PostsViewRecord> posts;
  final void Function(PostsViewRecord post) onTap;

  const _PinnedStrip({required this.posts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 20, 10),
          child: Text('BRA ATT VETA', style: theme.textTheme.labelSmall),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final highlighted = i == 0;
              final fg = highlighted ? colors.onPrimary : colors.onSurface;
              return SizedBox(
                width: 156,
                child: Material(
                  color: highlighted ? colors.primary : colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    side: highlighted
                        ? BorderSide.none
                        : BorderSide(color: colors.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTap(posts[i]),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.push_pin_outlined,
                            size: 20,
                            color: highlighted ? fg : colors.primary,
                          ),
                          Text(
                            posts[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostsViewRecord post;
  final VoidCallback onTap;

  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final excerpt = TextUtils.excerpt(post.description, maxLength: 180);
    final image = firstImageUrl(post.description);
    final meta = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
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
                Text(AppDateUtils.friendlyDay(post.created), style: meta),
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
                ),
                if (excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (image != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Image.network(
                      image,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                if (post.commentsCount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        post.commentsCount == 1
                            ? '1 kommentar'
                            : '${post.commentsCount} kommentarer',
                        style: meta,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
