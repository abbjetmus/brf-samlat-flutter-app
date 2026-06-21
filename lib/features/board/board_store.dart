import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

class BoardStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  BoardStore(this._pb, this._authStore) {
    _boardMeetings = Paginated<BoardMeetingsRecord>((page, perPage) async {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return const PageResult([], 0);

      final res = await _pb
          .collection(Collections.boardMeetings)
          .getList(
            page: page,
            perPage: perPage,
            filter: 'association="$assocId"',
            sort: '-start_at',
          );
      return PageResult(
        res.items.map((r) => BoardMeetingsRecord.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  late final Paginated<BoardMeetingsRecord> _boardMeetings;
  final _currentMeeting = ref<BoardMeetingsRecord?>(null);
  final _templates = ref<List<BoardMeetingTemplatesRecord>>([]);
  final _boardMembers = ref<List<UsersRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<BoardMeetingsRecord>> get boardMeetings => _boardMeetings.items;
  Ref<BoardMeetingsRecord?> get currentMeeting => _currentMeeting;
  Ref<List<BoardMeetingTemplatesRecord>> get templates => _templates;
  Ref<List<UsersRecord>> get boardMembers => _boardMembers;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _boardMeetings.loading;
  Ref<bool> get loadingMore => _boardMeetings.loadingMore;
  Ref<bool> get hasMore => _boardMeetings.hasMore;

  Future<void> getAllBoardMeetings() => _boardMeetings.refresh();
  Future<void> fetchNextBoardMeetings() => _boardMeetings.loadMore();

  /// Board members are the association's users that have at least one
  /// `association_role_types` role assigned.
  Future<bool> getBoardMembers() async {
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb
          .collection(Collections.users)
          .getFullList(
            filter:
                'association="$assocId" && association_role_types:length > 0',
            sort: 'name',
          );
      _boardMembers.value = records
          .map((r) => UsersRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error fetching board members: $e');
      return false;
    }
  }

  /// Assigns (or replaces) the association roles for a user, turning them into
  /// a board member. Passing an empty list removes them from the board.
  Future<bool> setBoardMemberRoles({
    required String userId,
    required List<String> roleTypeIds,
  }) async {
    _loading.value = true;
    try {
      await _pb
          .collection(Collections.users)
          .update(userId, body: {'association_role_types': roleTypeIds});
      await getBoardMembers();
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error updating board member: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  /// Removes a user from the board by clearing their association roles.
  Future<bool> removeBoardMember(String userId) =>
      setBoardMemberRoles(userId: userId, roleTypeIds: const []);

  Future<bool> getBoardMeeting(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.boardMeetings).getOne(id);
      _currentMeeting.value = BoardMeetingsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error fetching board meeting: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  /// Loads the templates available when creating a meeting: the association's
  /// own templates plus the shared system templates (mirrors the web app's
  /// `allBoardMeetingTemplates`).
  Future<bool> getTemplates() async {
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final results = await Future.wait([
        _pb
            .collection(Collections.boardMeetingTemplates)
            .getList(page: 1, perPage: 100, filter: 'association="$assocId"'),
        _pb
            .collection(Collections.systemBoardMeetingTemplates)
            .getList(page: 1, perPage: 100),
      ]);

      _templates.value = [
        for (final res in results)
          ...res.items.map(
            (r) => BoardMeetingTemplatesRecord.fromJson(r.toJson()),
          ),
      ];
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error fetching templates: $e');
      return false;
    }
  }

  Future<bool> createBoardMeeting({
    required String startAt,
    required String endAt,
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String meetingProtocolId,
    required List<dynamic> meetingProtocol,
    List<dynamic>? meetingAgenda,
    bool addToCalendar = false,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';

      final body = <String, dynamic>{
        'association': assocId,
        'start_at': startAt,
        'end_at': endAt,
        'street_address': streetAddress,
        'zip_code': zipCode,
        'locality': locality,
        'meeting_protocol_id': meetingProtocolId,
        'meeting_protocol': meetingProtocol,
        'add_to_calendar': addToCalendar,
      };

      if (meetingAgenda != null) body['meeting_agenda'] = meetingAgenda;

      await _pb.collection(Collections.boardMeetings).create(body: body);
      await getAllBoardMeetings();
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error creating board meeting: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updateBoardMeeting({
    required String id,
    required String startAt,
    required String endAt,
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String meetingProtocolId,
    List<dynamic>? meetingAgenda,
    List<dynamic>? meetingProtocol,
    bool addToCalendar = false,
  }) async {
    _loading.value = true;
    try {
      final body = <String, dynamic>{
        'start_at': startAt,
        'end_at': endAt,
        'street_address': streetAddress,
        'zip_code': zipCode,
        'locality': locality,
        'meeting_protocol_id': meetingProtocolId,
        'add_to_calendar': addToCalendar,
      };

      if (meetingAgenda != null) body['meeting_agenda'] = meetingAgenda;
      if (meetingProtocol != null) body['meeting_protocol'] = meetingProtocol;

      await _pb.collection(Collections.boardMeetings).update(id, body: body);
      await getBoardMeeting(id);
      await getAllBoardMeetings();
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error updating board meeting: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteBoardMeeting(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.boardMeetings).delete(id);
      await getAllBoardMeetings();
      return true;
    } catch (e) {
      debugPrint('BoardStore: Error deleting board meeting: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
