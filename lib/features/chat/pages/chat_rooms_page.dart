import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../widgets/chat_mute_options.dart';
import 'chat_room_page.dart';

/// Conversation list. flutter_chat_ui only renders a single conversation, so the
/// room list is a plain Flutter list that navigates into [ChatRoomPage].
class ChatRoomsPage extends CompositionWidget {
  static const String path = '/chat';

  const ChatRoomsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final chatStore = inject(chatStoreKey);
    final authStore = inject(authStoreKey);
    final theme = useTheme();

    onMounted(() {
      chatStore.getRooms();
      chatStore.subscribeRooms();
    });

    onUnmounted(() {
      chatStore.unsubscribeAll();
    });

    final openingBoardRoom = ref<bool>(false);

    // Styrelsen: medlemmarnas trådar (bara de med meddelanden) under "Att
    // hantera" tills någon markerar dem som hanterade ("Hanterade"; de kommer
    // tillbaka när medlemmen skriver igen), och styrelsens egen chatt under
    // "Bara styrelsen".
    final chatTab = ref<String>('open');

    // "Skriv till styrelsen": find-or-create the member's board room on the
    // server, then open it.
    // "Bara styrelsen" works the same way for the board's own chat.
    Future<void> openBoardRoom(
      BuildContext context, {
      bool internal = false,
    }) async {
      if (openingBoardRoom.value) return;
      openingBoardRoom.value = true;
      final roomId = internal
          ? await chatStore.openBoardInternalRoom()
          : await chatStore.openBoardRoom();
      openingBoardRoom.value = false;
      if (!context.mounted) return;
      if (roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatStore.lastError ?? 'Kunde inte öppna styrelsechatten.',
            ),
          ),
        );
        return;
      }
      context.push(
        '${ChatRoomPage.path}/$roomId',
        extra: internal ? 'Bara styrelsen' : 'Styrelsen',
      );
    }

    String preview(ChatMessagesRecord? last) {
      if (last == null) return 'Inga meddelanden';
      if (last.deleted) return 'Meddelandet har tagits bort';
      final content = last.content ?? '';
      if (content.isEmpty && last.files.isNotEmpty) return '📎 Bilaga';
      return content;
    }

    void showRoomOptions(BuildContext context, ChatRoomsRecord room) {
      // Every room is managed by the server: only mute, plus "Markera som
      // hanterad" for the board.
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
              if (chatStore.isInboxThread(room))
                ListTile(
                  leading: Icon(
                    room.isBoardHandled
                        ? Icons.unarchive_outlined
                        : Icons.check_circle_outline,
                  ),
                  title: Text(
                    room.isBoardHandled ? 'Öppna igen' : 'Markera som hanterad',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await chatStore.setBoardHandled(
                      room.id,
                      !room.isBoardHandled,
                    );
                    if (!context.mounted || ok) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          chatStore.lastError ?? 'Kunde inte uppdatera tråden.',
                        ),
                      ),
                    );
                  },
                ),
              ChatMuteTile(
                hostContext: context,
                chatStore: chatStore,
                roomId: room.id,
              ),
            ],
          ),
        ),
      );
    }

    return (context) {
      final me = authStore.currentUser.value?.id;
      final allRooms = chatStore.rooms.value;
      // Medlemmarnas trådar till styrelsen, bara de där någon har skrivit.
      final inboxThreads = allRooms
          .where(
            (r) =>
                chatStore.isInboxThread(r) &&
                chatStore.lastMessages.value[r.id] != null,
          )
          .toList();
      final inboxOpen = inboxThreads.where((r) => !r.isBoardHandled).toList();
      final inboxHandled = inboxThreads.where((r) => r.isBoardHandled).toList();
      final internalRoom = chatStore.boardInternalRoom;
      final isBoard =
          authStore.isBoardMember.value ||
          allRooms.any((r) => chatStore.isInboxThread(r) || r.boardInternal);
      // Medlemmen har bara raden Skriv till styrelsen.
      final myBoardRoom = isBoard
          ? null
          : allRooms.where((r) => r.boardContactUser == me).firstOrNull;
      final rooms = !isBoard
          ? <ChatRoomsRecord>[]
          : chatTab.value == 'open'
          ? inboxOpen
          : inboxHandled;
      final loading = chatStore.loadingRooms.value;
      final mutedIcon = Icon(
        Icons.notifications_off_outlined,
        size: 16,
        color: theme.value.colorScheme.onSurfaceVariant,
      );

      // Title with a small bell-off icon when the room's push is muted.
      Widget roomTitle(String text, bool muted, {TextStyle? style}) => Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (muted) ...[const SizedBox(width: 4), mutedIcon],
        ],
      );

      // A fixed row for a room the server owns: the member's "Skriv till
      // styrelsen" and the board's "Bara styrelsen".
      Widget fixedEntry({
        required String title,
        required String emptyText,
        required ChatRoomsRecord? room,
        required bool internal,
      }) {
        final unread = room == null ? 0 : chatStore.unreadCount(room.id);
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.groups_outlined, color: Colors.white),
            ),
            title: roomTitle(
              title,
              room != null && chatStore.isMuted(room.id),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              room == null
                  ? emptyText
                  : preview(chatStore.lastMessages.value[room.id]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: openingBoardRoom.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : unread > 0
                ? Badge(label: Text('$unread'))
                : const Icon(Icons.chevron_right),
            onTap: () => openBoardRoom(context, internal: internal),
            onLongPress: room == null
                ? null
                : () => showRoomOptions(context, room),
          ),
        );
      }

      final internalUnread = internalRoom == null
          ? 0
          : chatStore.unreadCount(internalRoom.id);

      return GradientScaffold(
        title: 'Meddelanden',
        body: Column(
          children: [
            HelpTip(
              // Eget id för styrelsens text. Nyckeln bygger om tipset när
              // läget ändras (rummen laddas efter första ritningen).
              key: ValueKey(isBoard ? 'chat-board' : 'chat-member'),
              id: isBoard ? 'chat-board' : 'chat-member',
              text: isBoard
                  ? 'Medlemmarnas meddelanden till styrelsen hamnar under '
                        'Att hantera. Håll fingret på en tråd och välj '
                        'Markera som hanterad när ni är klara. Den kommer '
                        'tillbaka om medlemmen skriver igen. Under Bara '
                        'styrelsen skriver ni med varandra i styrelsen.'
                  : 'Här skriver du till styrelsen. Alla i styrelsen ser '
                        'ditt meddelande och kan svara. Håll fingret på '
                        'raden för att stänga av notiser.',
            ),
            if (isBoard)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'open',
                        label: Text(
                          inboxOpen.isEmpty
                              ? 'Att hantera'
                              : 'Att hantera (${inboxOpen.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const ButtonSegment(
                        value: 'handled',
                        label: Text(
                          'Hanterade',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment(
                        value: 'internal',
                        label: Text(
                          internalUnread > 0
                              ? 'Bara styrelsen ($internalUnread)'
                              : 'Bara styrelsen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {chatTab.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => chatTab.value = v.first,
                  ),
                ),
              ),
            if (!isBoard)
              fixedEntry(
                title: 'Skriv till styrelsen',
                emptyText: 'Når hela styrelsen på en gång',
                room: myBoardRoom,
                internal: false,
              )
            else if (chatTab.value == 'internal')
              fixedEntry(
                title: 'Bara styrelsen',
                emptyText: 'Skriv med de andra i styrelsen',
                room: internalRoom,
                internal: true,
              ),
            Expanded(
              child: !isBoard || chatTab.value == 'internal'
                  ? const SizedBox.shrink()
                  : loading && rooms.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : rooms.isEmpty
                  ? Center(
                      child: Text(
                        chatTab.value == 'open'
                            ? 'Inget att hantera.'
                            : 'Inga hanterade meddelanden.',
                      ),
                    )
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
                            title: roomTitle(title, chatStore.isMuted(room.id)),
                            subtitle: Text(
                              preview(last),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
            ),
          ],
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
        room.isSystemRoom
            ? Icons.groups_outlined
            : (room.isGroup ? Icons.group_outlined : Icons.person_outline),
        color: AppTheme.primaryColor,
      ),
    );
  }
}
