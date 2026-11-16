import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart'
    show ClientException, PocketBase, UnsubscribeFunc;
import 'package:http/http.dart' as http;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

/// A file to upload with a chat message (image or any other file).
class ChatAttachment {
  final String filename;
  final Uint8List bytes;

  const ChatAttachment({required this.filename, required this.bytes});
}

/// Max size per chat file (chat_messages.files maxSize, 25 MB).
const int kChatMaxFileBytes = 25 * 1024 * 1024;

/// Max files per chat message (chat_messages.files maxSelect).
const int kChatMaxFiles = 10;

/// Backs the chat feature against the shared PocketBase chat_* collections.
/// Holds raw [ChatMessagesRecord]/[ChatRoomsRecord] data reactively; the
/// chat_room_page maps these into flutter_chat_ui messages. The same schema
/// feeds the Nuxt (vue-advanced-chat) client.
class ChatStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  ChatStore(this._pb, this._authStore);

  // Reactive state
  final _rooms = ref<List<ChatRoomsRecord>>([]);
  final _lastMessages = ref<Map<String, ChatMessagesRecord>>({});
  final _readReceipts = ref<List<ChatReadReceiptsRecord>>([]);
  final _messages = ref<List<ChatMessagesRecord>>([]);
  final _currentRoomId = ref<String?>(null);
  final _loadingRooms = ref<bool>(false);
  final _loadingMessages = ref<bool>(false);
  final _loadingOlderMessages = ref<bool>(false);
  final _hasMoreMessages = ref<bool>(false);

  /// How many messages to load per page (initial load + each scroll-up).
  static const int _messagesPageSize = 30;

  // Cache of resolved users for flutter_chat_ui's resolveUser callback.
  final Map<String, UsersRecord> _userCache = {};

  UnsubscribeFunc? _messagesUnsub;
  UnsubscribeFunc? _roomsUnsub;

  Ref<List<ChatRoomsRecord>> get rooms => _rooms;
  Ref<Map<String, ChatMessagesRecord>> get lastMessages => _lastMessages;
  Ref<List<ChatMessagesRecord>> get messages => _messages;
  Ref<String?> get currentRoomId => _currentRoomId;
  Ref<bool> get loadingRooms => _loadingRooms;
  Ref<bool> get loadingMessages => _loadingMessages;
  Ref<bool> get loadingOlderMessages => _loadingOlderMessages;

  /// True when there are older messages to load by scrolling up.
  Ref<bool> get hasMoreMessages => _hasMoreMessages;

  String? get _myId => _authStore.currentUser.value?.id;

  /// The server's message from the last failed write (e.g. the association
  /// only lets members write to the board), for a snackbar.
  String? lastError;

  String _errorMessage(Object e, String fallback) {
    if (e is ClientException) {
      final message = e.response['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  /// Members who are neither board nor admin may only write to the board when
  /// the association's chat_mode is 'board_only' (enforced server-side too).
  bool get boardOnlyRestricted =>
      (_authStore.association.value?.chatBoardOnly ?? false) &&
      !_authStore.isAdmin.value &&
      !_authStore.isBoardMember.value;

  /// The current user's own "Styrelsen" room, if it exists yet.
  ChatRoomsRecord? get myBoardRoom {
    final me = _myId;
    if (me == null) return null;
    return _rooms.value.where((r) => r.boardContactUser == me).firstOrNull;
  }

  // --- Rooms ------------------------------------------------------------

  Future<bool> getRooms() async {
    final me = _myId;
    if (me == null) return false;
    _loadingRooms.value = true;
    try {
      final result = await _pb
          .collection(Collections.chatRooms)
          .getFullList(
            filter: 'members.id ?= "$me"',
            sort: '-updated',
            expand: 'members',
          );
      final rooms = result
          .map((r) => ChatRoomsRecord.fromJson(r.toJson()))
          .toList();
      _rooms.value = rooms;

      // Cache member users for resolveUser.
      for (final room in rooms) {
        for (final u in room.memberUsers) {
          _userCache[u.id] = u;
        }
      }

      final receipts = await _pb
          .collection(Collections.chatReadReceipts)
          .getFullList(filter: 'user = "$me"');
      _readReceipts.value = receipts
          .map((r) => ChatReadReceiptsRecord.fromJson(r.toJson()))
          .toList();

      // Latest message per room for the list preview.
      final previews = <String, ChatMessagesRecord>{};
      for (final room in rooms) {
        try {
          final msgs = await _pb
              .collection(Collections.chatMessages)
              .getList(
                page: 1,
                perPage: 1,
                filter: 'room = "${room.id}"',
                sort: '-created',
                expand: 'sender',
              );
          if (msgs.items.isNotEmpty) {
            previews[room.id] = ChatMessagesRecord.fromJson(
              msgs.items.first.toJson(),
            );
          }
        } catch (_) {
          // Room may have no messages yet.
        }
      }
      _lastMessages.value = previews;
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error fetching rooms: $e');
      return false;
    } finally {
      _loadingRooms.value = false;
    }
  }

  int unreadCount(String roomId) {
    final last = _lastMessages.value[roomId];
    if (last == null) return 0;
    // A message I sent myself is never unread for me — don't badge it even
    // before the read receipt round-trips.
    if (last.sender == _myId) return 0;
    final receipt = _readReceipts.value
        .where((r) => r.room == roomId)
        .firstOrNull;
    if (receipt == null || receipt.lastReadMessage == null) return 1;
    return receipt.lastReadMessage == last.id ? 0 : 1;
  }

  String roomTitle(ChatRoomsRecord room) {
    // Board room: "Styrelsen" for the member, "Styrelsen – <member>" for the
    // board.
    if (room.isBoardRoom) {
      if (room.boardContactUser == _myId) return 'Styrelsen';
      final owner = room.memberUsers
          .where((u) => u.id == room.boardContactUser)
          .firstOrNull;
      final ownerName = owner == null
          ? 'medlem'
          : (owner.name.isNotEmpty ? owner.name : (owner.email ?? 'medlem'));
      return 'Styrelsen – $ownerName';
    }
    if (room.isGroup) {
      return (room.name?.isNotEmpty ?? false) ? room.name! : 'Grupp';
    }
    final me = _myId;
    final other = room.memberUsers.where((u) => u.id != me).firstOrNull;
    if (other != null) {
      return other.name.isNotEmpty ? other.name : (other.email ?? 'Chatt');
    }
    return room.name?.isNotEmpty == true ? room.name! : 'Chatt';
  }

  Future<String?> createRoom(
    List<String> userIds, {
    String? name,
    bool isGroup = false,
  }) async {
    final me = _myId;
    final associationId = _authStore.association.value?.id;
    if (me == null || associationId == null) return null;
    try {
      final allUsers = <String>{
        me,
        ...userIds.where((id) => id != me),
      }.toList();

      // Reuse an existing DM with the same two members.
      if (!isGroup && allUsers.length == 2) {
        final existing = _rooms.value.where((r) {
          if (r.isGroup) return false;
          return r.members.length == 2 &&
              r.members.contains(allUsers[0]) &&
              r.members.contains(allUsers[1]);
        }).firstOrNull;
        if (existing != null) return existing.id;
      }

      final record = await _pb
          .collection(Collections.chatRooms)
          .create(
            body: {
              'association': associationId,
              'name': name ?? '',
              'is_group': isGroup,
              'created_by': me,
              'members': allUsers,
            },
            expand: 'members',
          );
      final room = ChatRoomsRecord.fromJson(record.toJson());
      // The rooms realtime subscription (subscribeRooms) may already have
      // inserted this room from its own 'create' event; only prepend if absent
      // so the new conversation doesn't show up twice in the list.
      if (!_rooms.value.any((r) => r.id == room.id)) {
        _rooms.value = [room, ..._rooms.value];
      }
      for (final u in room.memberUsers) {
        _userCache[u.id] = u;
      }
      return room.id;
    } catch (e) {
      debugPrint('ChatStore: Error creating room: $e');
      lastError = _errorMessage(e, 'Kunde inte starta chatten.');
      return null;
    }
  }

  /// "Skriv till styrelsen": gets (or creates) the current member's board
  /// room via POST /api/chat/board-room. The server sets its members (the
  /// member + the whole board). Returns the room id, or null ([lastError]).
  Future<String?> openBoardRoom() async {
    try {
      final json = await _pb.send<Map<String, dynamic>>(
        '/api/chat/board-room',
        method: 'POST',
      );
      final room = ChatRoomsRecord.fromJson(json);
      final list = [..._rooms.value];
      final idx = list.indexWhere((r) => r.id == room.id);
      if (idx != -1) {
        list[idx] = room;
      } else {
        list.insert(0, room);
      }
      _rooms.value = list;
      for (final u in room.memberUsers) {
        _userCache[u.id] = u;
      }
      return room.id;
    } catch (e) {
      debugPrint('ChatStore: Error opening board room: $e');
      lastError = _errorMessage(e, 'Kunde inte öppna styrelsechatten.');
      return null;
    }
  }

  // --- Messages ---------------------------------------------------------

  Future<bool> getMessages(String roomId) async {
    _currentRoomId.value = roomId;
    _loadingMessages.value = true;
    _hasMoreMessages.value = false;
    try {
      // Load the newest page, then reverse to ascending (oldest -> newest) for
      // display. Older messages are paged in on scroll-up via [loadOlderMessages].
      final result = await _pb
          .collection(Collections.chatMessages)
          .getList(
            page: 1,
            perPage: _messagesPageSize,
            filter: 'room = "$roomId"',
            sort: '-created',
            expand: 'sender,reply_to',
          );
      _messages.value = result.items
          .map((r) => ChatMessagesRecord.fromJson(r.toJson()))
          .toList()
          .reversed
          .toList();
      _hasMoreMessages.value = result.totalPages > 1;
      for (final m in _messages.value) {
        if (m.senderUser != null) _userCache[m.sender] = m.senderUser!;
      }
      await markAsRead(roomId);
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error fetching messages: $e');
      return false;
    } finally {
      _loadingMessages.value = false;
    }
  }

  /// Loads the next page of older messages (scroll-up pagination), prepending
  /// them to [messages]. Cursor-based on the oldest loaded message's timestamp
  /// so concurrent realtime inserts don't shift an offset.
  Future<void> loadOlderMessages(String roomId) async {
    if (!_hasMoreMessages.value || _loadingOlderMessages.value) return;
    if (_currentRoomId.value != roomId) return;
    final oldestCreated = _messages.value.isNotEmpty
        ? _messages.value.first.created
        : null;
    if (oldestCreated == null || oldestCreated.isEmpty) return;

    _loadingOlderMessages.value = true;
    try {
      final result = await _pb
          .collection(Collections.chatMessages)
          .getList(
            page: 1,
            perPage: _messagesPageSize,
            filter: 'room = "$roomId" && created < "$oldestCreated"',
            sort: '-created',
            expand: 'sender,reply_to',
          );
      final older = result.items
          .map((r) => ChatMessagesRecord.fromJson(r.toJson()))
          .toList()
          .reversed
          .toList();
      for (final m in older) {
        if (m.senderUser != null) _userCache[m.sender] = m.senderUser!;
      }
      // Skip any already present (in case a realtime event raced in).
      final existingIds = _messages.value.map((m) => m.id).toSet();
      final fresh = older.where((m) => !existingIds.contains(m.id)).toList();
      _messages.value = [...fresh, ..._messages.value];
      _hasMoreMessages.value = result.totalPages > 1;
    } catch (e) {
      debugPrint('ChatStore: Error fetching older messages: $e');
    } finally {
      _loadingOlderMessages.value = false;
    }
  }

  Future<bool> sendMessage(
    String roomId,
    String content, {
    List<ChatAttachment>? attachments,
    String? replyToId,
  }) async {
    final me = _myId;
    if (me == null) return false;
    try {
      final files = <http.MultipartFile>[
        for (final a in attachments ?? const <ChatAttachment>[])
          http.MultipartFile.fromBytes('files', a.bytes, filename: a.filename),
      ];
      final body = <String, dynamic>{
        'room': roomId,
        'sender': me,
        'content': content,
        'deleted': false,
        'edited': false,
      };
      if (replyToId != null) body['reply_to'] = replyToId;
      await _pb
          .collection(Collections.chatMessages)
          .create(body: body, files: files, expand: 'sender,reply_to');
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error sending message: $e');
      lastError = _errorMessage(e, 'Kunde inte skicka meddelandet.');
      return false;
    }
  }

  Future<bool> editMessage(String messageId, String content) async {
    try {
      await _pb.collection(Collections.chatMessages).update(
        messageId,
        body: {'content': content, 'edited': true},
      );
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error editing message: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await _pb
          .collection(Collections.chatMessages)
          .update(messageId, body: {'deleted': true});
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error deleting message: $e');
      return false;
    }
  }

  Future<bool> updateRoom(String roomId, {String? name}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      await _pb
          .collection(Collections.chatRooms)
          .update(roomId, body: body, expand: 'members');
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error updating room: $e');
      return false;
    }
  }

  Future<bool> deleteRoom(String roomId) async {
    try {
      await _pb.collection(Collections.chatRooms).delete(roomId);
      _rooms.value = _rooms.value.where((r) => r.id != roomId).toList();
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error deleting room: $e');
      return false;
    }
  }

  Future<bool> leaveRoom(String roomId) async {
    final me = _myId;
    if (me == null) return false;
    try {
      final room = _rooms.value.where((r) => r.id == roomId).firstOrNull;
      if (room == null) return false;
      final newMembers = room.members.where((id) => id != me).toList();
      await _pb.collection(Collections.chatRooms).update(
        roomId,
        body: {'members': newMembers},
      );
      _rooms.value = _rooms.value.where((r) => r.id != roomId).toList();
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error leaving room: $e');
      return false;
    }
  }

  Future<bool> addMembers(String roomId, List<String> userIds) async {
    try {
      final room = _rooms.value.where((r) => r.id == roomId).firstOrNull;
      if (room == null) return false;
      final updated = {...room.members, ...userIds}.toList();
      await _pb.collection(Collections.chatRooms).update(
        roomId,
        body: {'members': updated},
        expand: 'members',
      );
      return true;
    } catch (e) {
      debugPrint('ChatStore: Error adding members: $e');
      return false;
    }
  }

  Future<void> markAsRead(String roomId) async {
    final me = _myId;
    if (me == null) return;
    final roomMsgs = _messages.value.where((m) => m.room == roomId).toList();
    if (roomMsgs.isEmpty) return;
    final lastId = roomMsgs.last.id;
    try {
      final existing = _readReceipts.value
          .where((r) => r.room == roomId && r.user == me)
          .firstOrNull;
      if (existing != null) {
        await _pb
            .collection(Collections.chatReadReceipts)
            .update(existing.id, body: {'last_read_message': lastId});
      } else {
        final record = await _pb
            .collection(Collections.chatReadReceipts)
            .create(
              body: {'room': roomId, 'user': me, 'last_read_message': lastId},
            );
        _readReceipts.value = [
          ..._readReceipts.value,
          ChatReadReceiptsRecord.fromJson(record.toJson()),
        ];
      }
    } catch (e) {
      debugPrint('ChatStore: Error marking as read: $e');
    }
  }

  // --- Users ------------------------------------------------------------

  Future<UsersRecord?> resolveUser(String id) async {
    final cached = _userCache[id];
    if (cached != null) return cached;
    try {
      final record = await _pb.collection(Collections.users).getOne(id);
      final user = UsersRecord.fromJson(record.toJson());
      _userCache[id] = user;
      return user;
    } catch (e) {
      debugPrint('ChatStore: Error resolving user $id: $e');
      return null;
    }
  }

  // --- Realtime ---------------------------------------------------------

  Future<void> subscribeMessages() async {
    _messagesUnsub ??= await _pb.collection(Collections.chatMessages).subscribe(
      '*',
      (e) {
        final record = e.record;
        if (record == null) return;
        final msg = ChatMessagesRecord.fromJson(record.toJson());
        if (msg.senderUser != null) _userCache[msg.sender] = msg.senderUser!;

        // Keep the room list preview fresh regardless of which room is open.
        if (e.action == 'create' || e.action == 'update') {
          _lastMessages.value = {..._lastMessages.value, msg.room: msg};
        }

        if (msg.room != _currentRoomId.value) return;
        final current = [..._messages.value];
        final idx = current.indexWhere((m) => m.id == msg.id);
        if (e.action == 'delete') {
          if (idx != -1) current.removeAt(idx);
        } else if (idx != -1) {
          current[idx] = msg;
        } else if (e.action == 'create') {
          current.add(msg);
          markAsRead(msg.room);
        }
        _messages.value = current;
      },
      expand: 'sender,reply_to',
    );
  }

  Future<void> subscribeRooms() async {
    _roomsUnsub ??= await _pb.collection(Collections.chatRooms).subscribe('*', (
      e,
    ) {
      final record = e.record;
      if (record == null) return;
      final room = ChatRoomsRecord.fromJson(record.toJson());
      final list = [..._rooms.value];
      final idx = list.indexWhere((r) => r.id == room.id);
      if (e.action == 'delete') {
        if (idx != -1) list.removeAt(idx);
      } else if (idx != -1) {
        list[idx] = room;
      } else {
        list.insert(0, room);
      }
      // Keep most-recent-activity first.
      list.sort((a, b) => (b.updated ?? '').compareTo(a.updated ?? ''));
      _rooms.value = list;
    }, expand: 'members');
  }

  Future<void> unsubscribeAll() async {
    await _messagesUnsub?.call();
    await _roomsUnsub?.call();
    _messagesUnsub = null;
    _roomsUnsub = null;
  }
}
