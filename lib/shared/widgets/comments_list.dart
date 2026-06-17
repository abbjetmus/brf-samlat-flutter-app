import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_theme.dart';

class CommentItem {
  final String id;
  final String comment;
  final String? created;
  final String? userId;
  final String? userName;
  final String? userAvatar;

  const CommentItem({
    required this.id,
    required this.comment,
    this.created,
    this.userId,
    this.userName,
    this.userAvatar,
  });
}

class CommentsList extends StatelessWidget {
  final List<CommentItem> comments;
  final String? currentUserId;
  final Future<void> Function(String comment) onAddComment;
  final Future<void> Function(String id, String comment)? onEditComment;
  final Future<void> Function(String id)? onDeleteComment;

  const CommentsList({
    super.key,
    required this.comments,
    this.currentUserId,
    required this.onAddComment,
    this.onEditComment,
    this.onDeleteComment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add comment button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: () => _showAddCommentDialog(context),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Kommentera'),
          ),
        ),

        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Inga kommentarer ännu.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final comment = comments[index];
              final isOwn = currentUserId != null && comment.userId == currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    (comment.userName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      comment.userName ?? 'Okänd',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppDateUtils.timeAgo(comment.created),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                subtitle: Text(comment.comment),
                trailing: isOwn
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditCommentDialog(context, comment);
                          } else if (value == 'delete') {
                            onDeleteComment?.call(comment.id);
                          }
                        },
                        itemBuilder: (context) => [
                          if (onEditComment != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Redigera'),
                            ),
                          if (onDeleteComment != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Radera', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }

  void _showAddCommentDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lägg till kommentar'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Skriv din kommentar...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAddComment(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Skicka'),
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(BuildContext context, CommentItem comment) {
    final controller = TextEditingController(text: comment.comment);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera kommentar'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onEditComment?.call(comment.id, controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }
}
