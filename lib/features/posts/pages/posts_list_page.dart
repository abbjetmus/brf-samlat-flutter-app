import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import 'post_detail_page.dart';
import 'create_post_page.dart';

class PostsListPage extends CompositionWidget {
  static const String path = '/posts';

  const PostsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final postsStore = inject(postsStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      postsStore.getAllPosts();
    });

    return (context) {
      final posts = postsStore.postsList.value;
      final loading = postsStore.loading.value;
      final canCreate = authStore.hasPermission('posts', CrudOperation.create);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Nyheter'),
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreatePostPage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : posts.isEmpty
                ? const Center(child: Text('Inga nyheter ännu.'))
                : RefreshIndicator(
                    onRefresh: () => postsStore.getAllPosts(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: post.pinAsGeneralInfo
                                ? const Icon(Icons.push_pin, color: Colors.orange)
                                : Icon(Icons.article_outlined, color: AppTheme.primaryColor),
                            title: Text(
                              post.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  AppDateUtils.timeAgo(post.created),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                if (post.commentsCount > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.comment_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${post.commentsCount}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('${PostDetailPage.path}/${post.id}'),
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
