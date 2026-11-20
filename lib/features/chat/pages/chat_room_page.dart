import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../chat_store.dart';
import '../widgets/chat_mute_options.dart';
import 'chat_media_page.dart';
import 'chat_search_page.dart';

class ChatRoomPage extends CompositionWidget {
  static const String path = '/chat/room';

  final String roomId;
  final String title;

  const ChatRoomPage({super.key, required this.roomId, required this.title});

  @override
  Widget Function(BuildContext) setup() {
    final chatStore = inject(chatStoreKey);
    final authStore = inject(authStoreKey);
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

    void showSnack(BuildContext context, String message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> sendAttachments(
      BuildContext context,
      List<ChatAttachment> picked,
      int skippedTooLarge,
    ) async {
      final attachments = picked.take(kChatMaxFiles).toList();
      final notes = <String>[
        if (skippedTooLarge > 0)
          '$skippedTooLarge fil(er) var för stora (max '
              '${byteToMegabyte(kChatMaxFileBytes)} MB per fil).',
        if (picked.length > kChatMaxFiles)
          'Högst $kChatMaxFiles filer per meddelande.',
      ];
      if (notes.isNotEmpty) showSnack(context, notes.join(' '));
      if (attachments.isEmpty) return;
      final ok = await chatStore.sendMessage(
        roomId,
        '',
        attachments: attachments,
        replyToId: replyingTo.value?.id,
      );
      if (!ok) {
        if (context.mounted) {
          showSnack(
            context,
            chatStore.lastError ?? 'Kunde inte skicka meddelandet.',
          );
        }
        return;
      }
      replyingTo.value = null;
    }

    Future<void> pickImages(BuildContext context) async {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      final attachments = <ChatAttachment>[];
      var skipped = 0;
      for (final x in picked) {
        final bytes = await x.readAsBytes();
        if (bytes.length > kChatMaxFileBytes) {
          skipped++;
          continue;
        }
        attachments.add(ChatAttachment(filename: x.name, bytes: bytes));
      }
      if (!context.mounted) return;
      await sendAttachments(context, attachments, skipped);
    }

    Future<void> pickFiles(BuildContext context) async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      final attachments = <ChatAttachment>[];
      var skipped = 0;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        if (f.size > kChatMaxFileBytes) {
          skipped++;
          continue;
        }
        attachments.add(ChatAttachment(filename: f.name, bytes: bytes));
      }
      if (!context.mounted) return;
      await sendAttachments(context, attachments, skipped);
    }

    // "Bifoga": choose between images (gallery) and any file.
    void chooseAttachment(BuildContext context) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Bild'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImages(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Fil'),
                subtitle: const Text('PDF, dokument och andra filer'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickFiles(context);
                },
              ),
            ],
          ),
        ),
      );
    }

    void showMessageOptions(
      BuildContext context,
      Message message,
      String currentUserId,
    ) {
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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

    // "Sök i chatten" / "Media och filer": load older pages until the message
    // is there, then scroll it to the middle of the screen.
    Future<void> jumpTo(BuildContext context, String? messageId) async {
      if (messageId == null) return;
      final found = await chatStore.loadUntilMessage(roomId, messageId);
      if (!context.mounted) return;
      if (!found) {
        showSnack(context, 'Meddelandet kunde inte visas.');
        return;
      }
      // Let the chat list lay out the loaded messages first.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await controller.scrollToMessage(
        messageId,
        alignment: 0.5,
        duration: const Duration(milliseconds: 400),
      );
    }

    void showRoomOptions(BuildContext context, ChatRoomsRecord room) {
      // All rooms are managed by the server (members follow the board), so
      // they only offer muting, plus "Markera som hanterad" for the board.
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Styrelsens inkorg: en medlems tråd till styrelsen.
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
                    final handled = !room.isBoardHandled;
                    final ok = await chatStore.setBoardHandled(
                      room.id,
                      handled,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? (handled
                                    ? 'Markerad som hanterad.'
                                    : 'Tråden är öppen igen.')
                              : (chatStore.lastError ??
                                    'Kunde inte uppdatera tråden.'),
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
      final currentUserId = authStore.currentUser.value?.id ?? '';
      final room = chatStore.rooms.value
          .where((r) => r.id == roomId)
          .firstOrNull;
      final replying = replyingTo.value;
      final mute = chatStore.activeMute(roomId);

      return GradientScaffold(
        title: title,
        // "Notiser avstängda till 18 nov 14:30" while the room is muted.
        subtitle: mute == null
            ? null
            : 'Notiser avstängda ${chatMuteUntilText(mute)}',
        actions: [
          HeaderIconButton(
            icon: Icons.search,
            tooltip: 'Sök i chatten',
            onPressed: () async {
              final id = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => ChatSearchPage(roomId: roomId),
                ),
              );
              if (context.mounted) await jumpTo(context, id);
            },
          ),
          HeaderIconButton(
            icon: Icons.photo_library_outlined,
            tooltip: 'Media och filer',
            onPressed: () async {
              final id = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => ChatMediaPage(roomId: roomId),
                ),
              );
              if (context.mounted) await jumpTo(context, id);
            },
          ),
          if (room != null)
            HeaderIconButton(
              icon: Icons.more_vert,
              tooltip: 'Alternativ',
              onPressed: () => showRoomOptions(context, room),
            ),
        ],
        body: Chat(
          chatController: controller,
          currentUserId: currentUserId,
          theme: _chatTheme(context),
          onAttachmentTap: () => chooseAttachment(context),
          onMessageLongPress:
              (ctx, message, {required index, required details}) {
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
            customMessageBuilder:
                (ctx, message, index, {required isSentByMe, groupStatus}) =>
                    _AttachmentsBubble(
                      message: message,
                      isSentByMe: isSentByMe,
                    ),
          ),
          onMessageSend: (text) async {
            final trimmed = text.trim();
            if (trimmed.isEmpty && replyingTo.value == null) return;
            final replyTo = replyingTo.value?.id;
            replyingTo.value = null;
            final ok = await chatStore.sendMessage(
              roomId,
              trimmed,
              replyToId: replyTo,
            );
            if (!ok && context.mounted) {
              showSnack(
                context,
                chatStore.lastError ?? 'Kunde inte skicka meddelandet.',
              );
            }
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
        surfaceContainer: isDark
            ? const Color(0xFF1E2A40)
            : const Color(0xFFE8F0EC),
      ),
    );
  }

  Message _toMessage(ChatMessagesRecord m) {
    final createdAt = DateTime.tryParse(m.created ?? '')?.toUtc();
    final text = m.deleted ? 'Meddelandet har tagits bort' : (m.content ?? '');

    if (!m.deleted && m.files.isNotEmpty) {
      // A single image keeps flutter_chat_ui's own image bubble.
      if (m.files.length == 1 && parseFilename(m.files.first).isImage) {
        return ImageMessage(
          id: m.id,
          authorId: m.sender,
          createdAt: createdAt,
          source: getImageUrl(Collections.chatMessages, m.id, m.files.first),
          text: m.content,
          replyToMessageId: m.replyTo,
        );
      }
      // Several files, or any non-image file: every file is shown
      // (_AttachmentsBubble) — images as thumbnails, other files as chips.
      return CustomMessage(
        id: m.id,
        authorId: m.sender,
        createdAt: createdAt,
        replyToMessageId: m.replyTo,
        metadata: {
          'text': m.content ?? '',
          'files': [
            for (final f in m.files)
              {
                'name': f,
                'url': getImageUrl(Collections.chatMessages, m.id, f),
              },
          ],
        },
      );
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

/// Chat bubble for a message with several files or non-image files: image
/// thumbnails and tappable file chips (opened in the browser/system viewer),
/// then the message text.
class _AttachmentsBubble extends StatelessWidget {
  final CustomMessage message;
  final bool isSentByMe;

  const _AttachmentsBubble({required this.message, required this.isSentByMe});

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Same colors as ChatRoomPage._chatTheme (sent = primary).
    final background = isSentByMe
        ? colorScheme.primary
        : (isDark ? const Color(0xFF1E2A40) : const Color(0xFFE8F0EC));
    final foreground = isSentByMe
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    final metadata = message.metadata ?? const {};
    final text = (metadata['text'] as String?) ?? '';
    final files = ((metadata['files'] as List?) ?? const [])
        .whereType<Map>()
        .map((f) => (name: '${f['name']}', url: '${f['url']}'))
        .toList();
    final images = files.where((f) => parseFilename(f.name).isImage).toList();
    final others = files.where((f) => !parseFilename(f.name).isImage).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (images.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final img in images)
                    GestureDetector(
                      onTap: () => _open(img.url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          img.url,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 110,
                            height: 110,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (images.isNotEmpty && others.isNotEmpty)
              const SizedBox(height: 6),
            for (final file in others)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ActionChip(
                  avatar: Icon(parseFilename(file.name).icon, size: 18),
                  label: Text(() {
                    final info = parseFilename(file.name);
                    return info.extension.isEmpty
                        ? info.name
                        : '${info.name}.${info.extension}';
                  }(), overflow: TextOverflow.ellipsis),
                  onPressed: () => _open(file.url),
                ),
              ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Text(text, style: TextStyle(color: foreground)),
              ),
          ],
        ),
      ),
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
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
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
