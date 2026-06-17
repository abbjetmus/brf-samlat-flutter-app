import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/models/pocketbase_models.dart';

/// Renders a single conversation with flutter_chat_ui. Raw PocketBase messages
/// from [ChatStore] are mapped into flutter_chat_core [Message]s and pushed into
/// an [InMemoryChatController]; [resolveUser] hydrates sender names/avatars from
/// the shared `users` collection.
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

    onMounted(() async {
      await chatStore.getMessages(roomId);
      await chatStore.subscribeMessages();
    });

    // Keep the controller in sync with the reactive message list.
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

    return (context) {
      final currentUserId = authStore.currentUser.value?.id ?? '';

      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Chat(
          chatController: controller,
          currentUserId: currentUserId,
          onMessageSend: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) return;
            chatStore.sendMessage(roomId, trimmed);
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

  Message _toMessage(ChatMessagesRecord m) {
    final createdAt = DateTime.tryParse(m.created ?? '')?.toUtc();
    final text = m.deleted ? 'Meddelandet har tagits bort' : (m.content ?? '');

    // Show the first image attachment as an image message; other files fall
    // back to a text message carrying the caption.
    if (!m.deleted && m.files.isNotEmpty) {
      final first = m.files.first;
      if (parseFilename(first).isImage) {
        return ImageMessage(
          id: m.id,
          authorId: m.sender,
          createdAt: createdAt,
          source: getImageUrl(Collections.chatMessages, m.id, first),
          text: m.content,
        );
      }
    }

    return TextMessage(
      id: m.id,
      authorId: m.sender,
      createdAt: createdAt,
      text: text,
    );
  }
}
