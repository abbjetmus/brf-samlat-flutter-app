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
    final theme = useTheme();

    onMounted(() {
      chatStore.getRooms();
      chatStore.subscribeRooms();
    });

    onUnmounted(() {
      chatStore.unsubscribeAll();
    });

    final openingBoardRoom = ref<bool>(false);

    // Styrelsens inkorg: medlemmarnas styrelsechattar ligger under "Till
    // styrelsen" (bara trådar med meddelanden); hanterade trådar under
    // "Hanterade" tills medlemmen skriver igen.
    final chatTab = ref<String>('mine');
    final inboxFilter = ref<String>('open');

    // "Skriv till styrelsen": find-or-create the member's board room on the
    // server, then open it.
    Future<void> openBoardRoom(BuildContext context) async {
      if (openingBoardRoom.value) return;
      openingBoardRoom.value = true;
      final roomId = await chatStore.openBoardRoom();
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
      context.push('${ChatRoomPage.path}/$roomId', extra: 'Styrelsen');
    }

    String preview(ChatMessagesRecord? last) {
      if (last == null) return 'Inga meddelanden';
      if (last.deleted) return 'Meddelandet har tagits bort';
      final content = last.content ?? '';
      if (content.isEmpty && last.files.isNotEmpty) return '📎 Bilaga';
      return content;
    }

    void showRoomOptions(BuildContext context, ChatRoomsRecord room) {
      // The board room is managed by the server: no leave/delete, only mute.
      final boardRoom = room.isBoardRoom;
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
              if (room.isGroup && !boardRoom)
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
              if (isCreator && !boardRoom)
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
      final me = authStore.currentUser.value?.id;
      // Members (not the board) always get a pinned "Skriv till styrelsen"
      // entry; their own board room is shown there instead of in the list.
      final showBoardEntry = !authStore.isBoardMember.value;
      final boardOnly = chatStore.boardOnly;
      final allRooms = chatStore.rooms.value;
      final myBoardRoom = showBoardEntry
          ? allRooms.where((r) => r.boardContactUser == me).firstOrNull
          : null;
      final ownRooms = (myBoardRoom == null
              ? allRooms
              : allRooms.where((r) => r.id != myBoardRoom.id))
          .where((r) => !chatStore.isInboxThread(r))
          .toList();
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
      final inboxUnread = inboxOpen
          .where((r) => chatStore.unreadCount(r.id) > 0)
          .length;
      final showInbox =
          authStore.isBoardMember.value ||
          allRooms.any(chatStore.isInboxThread);
      // "Bara styrelsen": styrelsen ser bara inkorgen och medlemmen bara sin
      // tråd med styrelsen (raden Skriv till styrelsen), så inga flikar.
      final showInboxTabs = showInbox && !boardOnly;
      final onInboxTab = showInbox && (boardOnly || chatTab.value == 'board');
      // Eget id per läge, så att rätt text syns även för den som har stängt
      // en annan variant.
      final helpId = boardOnly
          ? (showInbox ? 'chat-board-only-inbox' : 'chat-board-only')
          : (showInboxTabs ? 'chat-board-inbox' : 'chat');
      final rooms = onInboxTab
          ? (inboxFilter.value == 'open' ? inboxOpen : inboxHandled)
          : boardOnly
          ? <ChatRoomsRecord>[]
          : ownRooms;
      final loading = chatStore.loadingRooms.value;
      final boardUnread =
          myBoardRoom == null ? 0 : chatStore.unreadCount(myBoardRoom.id);
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

      final boardEntry = showBoardEntry
          ? Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(
                    Icons.groups_outlined,
                    color: Colors.white,
                  ),
                ),
                title: roomTitle(
                  'Skriv till styrelsen',
                  myBoardRoom != null && chatStore.isMuted(myBoardRoom.id),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  myBoardRoom == null
                      ? 'Når hela styrelsen på en gång'
                      : preview(chatStore.lastMessages.value[myBoardRoom.id]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: openingBoardRoom.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : boardUnread > 0
                        ? Badge(label: Text('$boardUnread'))
                        : const Icon(Icons.chevron_right),
                onTap: () => openBoardRoom(context),
                onLongPress: myBoardRoom == null
                    ? null
                    : () => showRoomOptions(context, myBoardRoom),
              ),
            )
          : null;

      return GradientScaffold(
        title: 'Meddelanden',
        // With chat_mode 'board_only', members can't start conversations.
        floatingActionButton: boardOnly
            ? null
            : FloatingActionButton(
                onPressed: () => context.push(NewChatPage.path),
                child: const Icon(Icons.add_comment_outlined),
              ),
        body: Column(
          children: [
            HelpTip(
              // Eget id för styrelsens text, så att den syns även för den som
              // har stängt den vanliga hjälpen. Nyckeln bygger om tipset när
              // läget ändras (rummen laddas efter första ritningen).
              key: ValueKey(helpId),
              id: helpId,
              text: boardOnly && showInbox
                  ? 'Föreningen använder chatten bara för kontakt mellan '
                        'medlemmar och styrelsen. Här ser du medlemmarnas '
                        'meddelanden till styrelsen. Håll fingret på en tråd '
                        'och välj Markera som hanterad när ni är klara. Den '
                        'kommer tillbaka om medlemmen skriver igen.'
                  : boardOnly
                  ? 'Föreningen använder chatten bara för kontakt mellan '
                        'medlemmar och styrelsen. Tryck på Skriv till '
                        'styrelsen för att nå hela styrelsen.'
                  : showInboxTabs
                  ? 'Medlemmarnas meddelanden till styrelsen samlas under '
                        'Till styrelsen. Håll fingret på en tråd och välj '
                        'Markera som hanterad när ni är klara. Den kommer '
                        'tillbaka om medlemmen skriver igen.'
                  : 'Tryck på + och välj en eller flera personer för att '
                      'starta en konversation. Skriv till styrelsen når hela '
                      'styrelsen på en gång. Håll fingret på en konversation '
                      'för att stänga av notiser, lämna den, eller radera den '
                      'om du startade den.',
            ),
            if (showInboxTabs)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(
                        value: 'mine',
                        label: Text('Mina chattar'),
                      ),
                      ButtonSegment(
                        value: 'board',
                        label: Text(
                          inboxUnread > 0
                              ? 'Till styrelsen ($inboxUnread)'
                              : 'Till styrelsen',
                        ),
                      ),
                    ],
                    selected: {chatTab.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => chatTab.value = v.first,
                  ),
                ),
              ),
            if (onInboxTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Att hantera (${inboxOpen.length})'),
                      selected: inboxFilter.value == 'open',
                      onSelected: (_) => inboxFilter.value = 'open',
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Hanterade (${inboxHandled.length})'),
                      selected: inboxFilter.value == 'handled',
                      onSelected: (_) => inboxFilter.value = 'handled',
                    ),
                  ],
                ),
              ),
            if (!onInboxTab) ?boardEntry,
            Expanded(
              child: loading && rooms.isEmpty
            ? const Center(child: CircularProgressIndicator())
            // "Bara styrelsen": medlemmen har bara raden Skriv till styrelsen.
            : boardOnly && !onInboxTab
                ? const SizedBox.shrink()
            : rooms.isEmpty
                ? Center(
                    child: Text(
                      onInboxTab
                          ? (inboxFilter.value == 'open'
                                ? 'Inget att hantera.'
                                : 'Inga hanterade meddelanden.')
                          : showBoardEntry
                          ? 'Inga andra konversationer ännu.'
                          : 'Inga konversationer ännu.',
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
        room.isBoardRoom
            ? Icons.groups_outlined
            : (room.isGroup ? Icons.group_outlined : Icons.person_outline),
        color: AppTheme.primaryColor,
      ),
    );
  }
}
