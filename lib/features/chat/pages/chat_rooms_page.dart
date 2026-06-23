import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'chat_room_page.dart';
import 'new_chat_page.dart';

/// Conversation list. flutter_chat_ui only renders a single conversation, so the
/// room list is a plain Flutter list that navigates into [ChatRoomPage].
class ChatRoomsPage extends CompositionWidget {
  static const String path = '/chat';

  const ChatRoomsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final chatStore = inject(chatStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      chatStore.getRooms();
      chatStore.subscribeRooms();
    });

    onUnmounted(() {
      chatStore.unsubscribeAll();
    });

    void showRoomOptions(BuildContext context, ChatRoomsRecord room) {
      final currentUserId = authStore.currentUser.value?.id;
      final isCreator = room.createdBy == currentUserId;
      final title = chatStore.roomTitle(room);

      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: const Text('Öppna'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('${ChatRoomPage.path}/${room.id}', extra: title);
                },
              ),
              if (room.isGroup)
                ListTile(
                  leading: const Icon(Icons.exit_to_app_outlined),
                  title: const Text('Lämna chatt'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dlg) => AlertDialog(
                        title: const Text('Lämna chatt'),
                        content: Text('Vill du lämna "$title"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlg, false),
                            child: const Text('Avbryt'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dlg, true),
                            child: const Text('Lämna'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await chatStore.leaveRoom(room.id);
                    }
                  },
                ),
              if (isCreator)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Radera chatt',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dlg) => AlertDialog(
                        title: const Text('Radera chatt'),
                        content: Text('Vill du permanent radera "$title"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlg, false),
                            child: const Text('Avbryt'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(dlg).colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(dlg, true),
                            child: const Text('Radera'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await chatStore.deleteRoom(room.id);
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    return (context) {
      final rooms = chatStore.rooms.value;
      final loading = chatStore.loadingRooms.value;

      return GradientScaffold(
        title: 'Meddelanden',
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push(NewChatPage.path),
          child: const Icon(Icons.add_comment_outlined),
        ),
        body: loading && rooms.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : rooms.isEmpty
                ? const Center(child: Text('Inga konversationer ännu.'))
                : RefreshIndicator(
                    onRefresh: () => chatStore.getRooms(),
                    child: ListView.separated(
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final title = chatStore.roomTitle(room);
                        final last = chatStore.lastMessages.value[room.id];
                        final unread = chatStore.unreadCount(room.id);
                        return ListTile(
                          leading: _RoomAvatar(room: room, title: title),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: last != null
                              ? Text(
                                  last.deleted
                                      ? 'Meddelandet har tagits bort'
                                      : (last.content ?? ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const Text('Inga meddelanden'),
                          trailing: unread > 0
                              ? Badge(label: Text('$unread'))
                              : const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '${ChatRoomPage.path}/${room.id}',
                            extra: title,
                          ),
                          onLongPress: () => showRoomOptions(context, room),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}

class _RoomAvatar extends StatelessWidget {
  final ChatRoomsRecord room;
  final String title;

  const _RoomAvatar({required this.room, required this.title});

  @override
  Widget build(BuildContext context) {
    if (room.avatar != null && room.avatar!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(
          getImageUrl(Collections.chatRooms, room.id, room.avatar!),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      child: Icon(
        room.isGroup ? Icons.group_outlined : Icons.person_outline,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
