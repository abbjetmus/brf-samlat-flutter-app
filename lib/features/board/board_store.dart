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
  final _loading = ref<bool>(false);

  Ref<List<BoardMeetingsRecord>> get boardMeetings => _boardMeetings.items;
  Ref<BoardMeetingsRecord?> get currentMeeting => _currentMeeting;
  Ref<List<BoardMeetingTemplatesRecord>> get templates => _templates;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _boardMeetings.loading;
  Ref<bool> get loadingMore => _boardMeetings.loadingMore;
  Ref<bool> get hasMore => _boardMeetings.hasMore;

  Future<void> getAllBoardMeetings() => _boardMeetings.refresh();
  Future<void> fetchNextBoardMeetings() => _boardMeetings.loadMore();

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

  Future<bool> getTemplates() async {
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb
          .collection(Collections.boardMeetingTemplates)
          .getList(page: 1, perPage: 100, filter: 'association="$assocId"');
      _templates.value = records.items
          .map((r) => BoardMeetingTemplatesRecord.fromJson(r.toJson()))
          .toList();
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
