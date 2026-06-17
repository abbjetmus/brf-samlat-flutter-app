import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/comments_list.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class PostDetailPage extends CompositionWidget {
  static const String path = '/posts/detail';

  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  Widget Function(BuildContext) setup() {
    final postsStore = inject(postsStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      postsStore.getPost(postId);
      postsStore.getComments(postId);
    });

    return (context) {
      final post = postsStore.currentPost.value;
      final comments = postsStore.comments.value;
      final loading = postsStore.loading.value;
      final currentUserId = authStore.currentUser.value?.id;
      final canEdit = authStore.hasPermission('posts', CrudOperation.update);
      final canDelete = authStore.hasPermission('posts', CrudOperation.delete);

      if (loading && post == null) {
        return const GradientScaffold(
          title: 'Nyhet',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (post == null) {
        return const GradientScaffold(
          title: 'Nyhet',
          body: Center(child: Text('Nyhet hittades inte.')),
        );
      }

      return GradientScaffold(
        title: 'Nyhet',
        actions: [
            if (canDelete)
              HeaderIconButton(
                icon: Icons.delete_outline,
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera nyhet',
                    message: 'Är du säker på att du vill radera denna nyhet?',
                    okLabel: 'Radera',
                    okColor: Colors.red,
                  );
                  if (confirmed) {
                    await postsStore.deletePost(post.id);
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  }
                },
              ),
          ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.pinAsGeneralInfo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Chip(
                          avatar: const Icon(Icons.push_pin, size: 16),
                          label: const Text('Allmän information'),
                          backgroundColor: Colors.orange.shade50,
                        ),
                      ),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppDateUtils.formatDateLong(post.created),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Post body
              Padding(
                padding: const EdgeInsets.all(16),
                child: RichDescription(html: post.description),
              ),

              // Calendar info
              if (post.addToCalendar && post.startAt != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start: ${AppDateUtils.formatDateTime(post.startAt)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (post.endAt != null)
                              Text(
                                'Slut: ${AppDateUtils.formatDateTime(post.endAt)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Comments section
              if (post.commentsAllowed) ...[
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
                      userName = (expandUser.first as Map<String, dynamic>)['name'] as String?;
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
                  onAddComment: (comment) => postsStore.addComment(postId, comment),
                  onEditComment: canEdit
                      ? (id, comment) => postsStore.updateComment(id, comment, postId)
                      : null,
                  onDeleteComment: canDelete
                      ? (id) => postsStore.deleteComment(id, postId)
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
