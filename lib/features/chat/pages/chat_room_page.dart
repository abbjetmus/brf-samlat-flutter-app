import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class ChatRoomPage extends CompositionWidget {
  static const String path = '/chat/room';

  final String roomId;
  final String title;

  const ChatRoomPage({super.key, required this.roomId, required this.title});

  @override
  Widget Function(BuildContext) setup() {
    final chatStore = inject(chatStoreKey);
    final authStore = inject(authStoreKey);
    final usersStore = inject(usersStoreKey);
    final controller = InMemoryChatController();
    final replyingTo = ref<ChatMessagesRecord?>(null);

    onMounted(() async {
      await chatStore.getMessages(roomId);
      await chatStore.subscribeMessages();
    });

    watchEffect(() {
      final mapped = chatStore.messages.value
          .where((m) => m.room == roomId)
          .map(_toMessage)
          .toList();
      controller.setMessages(mapped);
    });

    onUnmounted(() {
      controller.dispose();
    });

    Future<void> pickImages() async {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isEmpty) return;
      final files = picked.map((x) => File(x.path)).toList();
      await chatStore.sendMessage(
        roomId,
        '',
        imageFiles: files,
        replyToId: replyingTo.value?.id,
      );
      replyingTo.value = null;
    }

    void showMessageOptions(BuildContext context, Message message, String currentUserId) {
      final isMe = message.authorId == currentUserId;
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Svara'),
                onTap: () {
                  Navigator.pop(ctx);
                  final record = chatStore.messages.value
                      .where((m) => m.id == message.id)
                      .firstOrNull;
                  replyingTo.value = record;
                },
              ),
              if (isMe && message is! TextMessage || isMe)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Ta bort meddelande',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    chatStore.deleteMessage(message.id);
                  },
                ),
            ],
          ),
        ),
      );
    }

    void showRenameDialog(BuildContext context, ChatRoomsRecord room) {
      showDialog(
        context: context,
        builder: (_) => _RenameRoomDialog(
          initialName: room.name ?? '',
          onConfirm: (name) => chatStore.updateRoom(room.id, name: name),
        ),
      );
    }

    void showAddMembersDialog(BuildContext context, ChatRoomsRecord room) {
      usersStore.getUsers();
      showDialog(
        context: context,
        builder: (_) => _AddMembersDialog(
          room: room,
          onConfirm: (ids) => chatStore.addMembers(room.id, ids),
        ),
      );
    }

    Future<void> showLeaveConfirm(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lämna chatt'),
          content: const Text('Vill du lämna den här konversationen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lämna'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await chatStore.leaveRoom(roomId);
        if (context.mounted) context.pop();
      }
    }

    Future<void> showDeleteConfirm(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Radera chatt'),
          content: const Text('Vill du permanent radera den här konversationen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Radera'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await chatStore.deleteRoom(roomId);
        if (context.mounted) context.pop();
      }
    }

    void showRoomOptions(BuildContext context, ChatRoomsRecord room, String currentUserId) {
      final isCreator = room.createdBy == currentUserId;
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (room.isGroup) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Byt namn'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showRenameDialog(context, room);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_outlined),
                  title: const Text('Lägg till deltagare'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddMembersDialog(context, room);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_outlined),
                  title: const Text('Lämna chatt'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showLeaveConfirm(context);
                  },
                ),
              ],
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
                  onTap: () {
                    Navigator.pop(ctx);
                    showDeleteConfirm(context);
                  },
                ),
            ],
          ),
        ),
      );
    }

    return (context) {
      final currentUserId = authStore.currentUser.value?.id ?? '';
      final room = chatStore.rooms.value
          .where((r) => r.id == roomId)
          .firstOrNull;
      final replying = replyingTo.value;

      return GradientScaffold(
        title: title,
        actions: [
          if (room != null && (room.isGroup || room.createdBy == currentUserId))
            HeaderIconButton(
              icon: Icons.more_vert,
              onPressed: () => showRoomOptions(context, room, currentUserId),
            ),
        ],
        body: Chat(
          chatController: controller,
          currentUserId: currentUserId,
          theme: _chatTheme(context),
          onAttachmentTap: () => pickImages(),
          onMessageLongPress: (ctx, message, {required index, required details}) {
            showMessageOptions(context, message, currentUserId);
          },
          builders: Builders(
            composerBuilder: (ctx) => Composer(
              topWidget: replying != null
                  ? _ReplyPreview(
                      record: replying,
                      onCancel: () => replyingTo.value = null,
                    )
                  : null,
              hintText: 'Skriv ett meddelande...',
            ),
            chatAnimatedListBuilder: (ctx, itemBuilder) => ChatAnimatedList(
              itemBuilder: itemBuilder,
              onEndReached: () => chatStore.loadOlderMessages(roomId),
            ),
            emptyChatListBuilder: (ctx) =>
                const EmptyChatList(text: 'Inga meddelanden än'),
          ),
          onMessageSend: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty && replyingTo.value == null) return;
            chatStore.sendMessage(
              roomId,
              trimmed,
              replyToId: replyingTo.value?.id,
            );
            replyingTo.value = null;
          },
          resolveUser: (UserID id) async {
            final user = await chatStore.resolveUser(id);
            if (user == null) return User(id: id);
            return User(
              id: id,
              name: user.name.isNotEmpty ? user.name : (user.email ?? ''),
              imageSource: (user.avatar != null && user.avatar!.isNotEmpty)
                  ? getImageUrl(Collections.users, user.id, user.avatar!)
                  : null,
            );
          },
        ),
      );
    };
  }

  /// Chat theme derived from the app [ThemeData], with an explicit
  /// received-bubble color. The app's [ColorScheme] doesn't define
  /// `surfaceContainer` (what flutter_chat_ui paints received bubbles with), so
  /// it falls back to a near-white shade that's invisible on the white chat
  /// surface — override it with a tint that clearly separates from the
  /// background in both light and dark mode.
  ChatTheme _chatTheme(BuildContext context) {
    final base = ChatTheme.fromThemeData(Theme.of(context));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return base.copyWith(
      colors: base.colors.copyWith(
        surfaceContainer:
            isDark ? const Color(0xFF1E2A40) : const Color(0xFFE8F0EC),
      ),
    );
  }

  Message _toMessage(ChatMessagesRecord m) {
    final createdAt = DateTime.tryParse(m.created ?? '')?.toUtc();
    final text = m.deleted ? 'Meddelandet har tagits bort' : (m.content ?? '');

    if (!m.deleted && m.files.isNotEmpty) {
      final first = m.files.first;
      if (parseFilename(first).isImage) {
        return ImageMessage(
          id: m.id,
          authorId: m.sender,
          createdAt: createdAt,
          source: getImageUrl(Collections.chatMessages, m.id, first),
          text: m.content,
          replyToMessageId: m.replyTo,
        );
      }
    }

    return TextMessage(
      id: m.id,
      authorId: m.sender,
      createdAt: createdAt,
      text: text,
      replyToMessageId: m.replyTo,
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessagesRecord record;
  final VoidCallback onCancel;

  const _ReplyPreview({required this.record, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = record.deleted
        ? 'Meddelandet har tagits bort'
        : (record.content?.isNotEmpty == true
            ? record.content!
            : record.files.isNotEmpty
                ? '📎 Bilaga'
                : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Svarar på',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _RenameRoomDialog extends CompositionWidget {
  final String initialName;
  final Future<bool> Function(String) onConfirm;

  const _RenameRoomDialog({required this.initialName, required this.onConfirm});

  @override
  Widget Function(BuildContext) setup() {
    final (ctrl, name, _) = useTextEditingController(text: initialName);
    final saving = ref(false);

    return (context) => AlertDialog(
          title: const Text('Byt namn'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Gruppnamn'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: saving.value || name.value.trim().isEmpty
                  ? null
                  : () async {
                      saving.value = true;
                      await onConfirm(name.value.trim());
                      if (context.mounted) Navigator.pop(context);
                    },
              child: saving.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spara'),
            ),
          ],
        );
  }
}

class _AddMembersDialog extends CompositionWidget {
  final ChatRoomsRecord room;
  final Future<bool> Function(List<String>) onConfirm;

  const _AddMembersDialog({required this.room, required this.onConfirm});

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final (_, query, _) = useTextEditingController();
    final selected = ref<Set<String>>({});
    final saving = ref(false);

    return (context) {
      final meId = authStore.currentUser.value?.id;
      final existingIds = {...room.members};
      final q = query.value.toLowerCase();
      final users = usersStore.users.value
          .where((u) => u.id != meId && !existingIds.contains(u.id))
          .where((u) =>
              q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              (u.email ?? '').toLowerCase().contains(q))
          .toList();

      return AlertDialog(
        title: const Text('Lägg till deltagare'),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Sök användare',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => query.value = v,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final isSelected = selected.value.contains(u.id);
                    return CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      title: Text(u.name.isNotEmpty ? u.name : (u.email ?? '')),
                      onChanged: (_) {
                        final next = {...selected.value};
                        isSelected ? next.remove(u.id) : next.add(u.id);
                        selected.value = next;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: saving.value || selected.value.isEmpty
                ? null
                : () async {
                    saving.value = true;
                    await onConfirm(selected.value.toList());
                    if (context.mounted) Navigator.pop(context);
                  },
            child: saving.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lägg till'),
          ),
        ],
      );
    };
  }
}
