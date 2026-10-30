import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/permissions_utils.dart';
import '../auth/auth_store.dart' as auth;
import '../signatures/signatures_store.dart'
    show MeetingSignatures, Signature, SignerInput;
import 'general_meetings_models.dart';

/// Föreningsstämma. Medlemmar läser stämmor och dagordning, lämnar motioner,
/// registrerar fullmakt, röstar och läser det justerade protokollet. Den som
/// har `update` på general_meetings (styrelsen) leder stämman: skapar och
/// redigerar den, skickar kallelsen, sköter röstlängd, fullmakter, motioner,
/// omröstningar och protokoll, och skickar protokollet för justering.
///
/// Regler och kontroller ligger på servern (brf-samlat-pb: API-regler +
/// collections/general_meetings.pb.js + api/general_meetings.pb.js). Metoder
/// som kan nekas av servern kastar [ClientException] — använd
/// [generalMeetingErrorMessage] för att visa serverns svenska meddelande.
class GeneralMeetingsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  GeneralMeetingsStore(this._pb, this._authStore) {
    _meetings = Paginated<GeneralMeeting>((page, perPage) async {
      final assocId = _assocId;
      if (assocId.isEmpty) return const PageResult([], 0);
      final res = await _pb
          .collection(GeneralMeetingCollections.meetings)
          .getList(
            page: page,
            perPage: perPage,
            filter: _pb.filter('association = {:a}', {'a': assocId}),
            sort: '-start_at',
          );
      return PageResult(
        res.items.map((r) => GeneralMeeting.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  late final Paginated<GeneralMeeting> _meetings;

  Ref<List<GeneralMeeting>> get meetings => _meetings.items;
  Ref<bool> get listLoading => _meetings.loading;
  Ref<bool> get loadingMore => _meetings.loadingMore;
  Ref<bool> get hasMore => _meetings.hasMore;

  Future<void> getMeetings() => _meetings.refresh();
  Future<void> fetchNextMeetings() => _meetings.loadMore();

  String get _assocId => _authStore.association.value?.id ?? '';
  String get currentUserId => _authStore.currentUser.value?.id ?? '';

  /// Leda stämman (samma nyckel som webben: general_meetings + update).
  bool get canManage =>
      _authStore.hasPermission('general_meetings', CrudOperation.update);

  /// Ta bort andras motioner och fullmakter.
  bool get canDelete =>
      _authStore.hasPermission('general_meetings', CrudOperation.delete);

  // --- Stämman (styrelsen). Metoderna kastar vid fel.

  Future<GeneralMeeting> createMeeting(Map<String, dynamic> body) async {
    final r = await _pb
        .collection(GeneralMeetingCollections.meetings)
        .create(body: {...body, 'association': _assocId, 'status': 'utkast'});
    return GeneralMeeting.fromJson(r.toJson());
  }

  Future<GeneralMeeting> updateMeeting(
    String id,
    Map<String, dynamic> body,
  ) async {
    final r = await _pb
        .collection(GeneralMeetingCollections.meetings)
        .update(id, body: body);
    return GeneralMeeting.fromJson(r.toJson());
  }

  Future<void> deleteMeeting(String id) =>
      _pb.collection(GeneralMeetingCollections.meetings).delete(id);

  Future<GeneralMeetingSettings> getSettings() async {
    final res = await _pb.send('/api/general-meeting-settings');
    return GeneralMeetingSettings.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  Future<GeneralMeetingSettings> saveSettings(
    GeneralMeetingSettings settings,
  ) async {
    final res = await _pb.send(
      '/api/general-meeting-settings',
      method: 'PUT',
      body: settings.toJson(),
    );
    return GeneralMeetingSettings.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  Future<NoticeCheck> noticeCheck(String meetingId) async {
    final res = await _pb.send('/api/general-meetings/$meetingId/notice-check');
    return NoticeCheck.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Skickar kallelsen. Returnerar (antal mejl, antal misslyckade mejl).
  Future<(int, int)> publish(
    String meetingId, {
    required bool confirmOutsidePeriod,
  }) async {
    final res = await _pb.send(
      '/api/general-meetings/$meetingId/publish',
      method: 'POST',
      body: {'confirm_outside_period': confirmOutsidePeriod},
    );
    final m = res is Map ? res : const {};
    return (
      (m['emailed'] as num?)?.toInt() ?? 0,
      (m['email_failed'] as num?)?.toInt() ?? 0,
    );
  }

  // --- Dagordning (styrelsen). Kastar vid fel.

  Future<void> createItem(Map<String, dynamic> body) => _pb
      .collection(GeneralMeetingCollections.items)
      .create(body: {...body, 'association': _assocId});

  Future<void> updateItem(String id, Map<String, dynamic> body) =>
      _pb.collection(GeneralMeetingCollections.items).update(id, body: body);

  Future<void> deleteItem(String id) =>
      _pb.collection(GeneralMeetingCollections.items).delete(id);

  // --- Röstlängd (styrelsen)

  Future<List<GeneralMeetingVoter>> getVoters(String meetingId) async {
    final records = await _pb
        .collection(GeneralMeetingCollections.voters)
        .getFullList(
          filter: _pb.filter('general_meeting = {:m}', {'m': meetingId}),
          sort: 'label',
        );
    return records
        .map((r) => GeneralMeetingVoter.fromJson(r.toJson()))
        .toList();
  }

  Future<GeneralMeetingVoter> updateVoter(
    String id,
    Map<String, dynamic> body,
  ) async {
    final r = await _pb
        .collection(GeneralMeetingCollections.voters)
        .update(id, body: body);
    return GeneralMeetingVoter.fromJson(r.toJson());
  }

  /// Läser in bostäder och boende igen. Returnerar (tillagda, borttagna).
  Future<(int, int)> regenerateVoters(String meetingId) async {
    final res = await _pb.send(
      '/api/general-meetings/$meetingId/voters/generate',
      method: 'POST',
    );
    final m = res is Map ? res : const {};
    return (
      (m['added'] as num?)?.toInt() ?? 0,
      (m['removed'] as num?)?.toInt() ?? 0,
    );
  }

  // --- Justering av protokollet (samma motor som styrelsemötena, kind general)

  Future<MeetingSignatures> getSignatures(String meetingId) async {
    final res = await _pb.send('/api/general-meetings/$meetingId/signatures');
    final m = Map<String, dynamic>.from(res as Map);
    return MeetingSignatures(
      m['current_document_hash'] as String? ?? '',
      _signatures(m['signatures']),
    );
  }

  Future<List<Signature>> requestSignatures(
    String meetingId,
    List<SignerInput> signers,
  ) async {
    final res = await _pb.send(
      '/api/general-meetings/$meetingId/signatures',
      method: 'POST',
      body: {'signers': signers.map((s) => s.toJson()).toList()},
    );
    return _signatures((res as Map)['signatures']);
  }

  Future<void> cancelSignatures(String meetingId) =>
      _pb.send('/api/general-meetings/$meetingId/signatures', method: 'DELETE');

  static List<Signature> _signatures(dynamic raw) => (raw as List? ?? const [])
      .map((e) => Signature.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  /// Föreningens användare (för justerare).
  Future<List<UsersRecord>> associationUsers() async {
    if (_assocId.isEmpty) return [];
    final records = await _pb
        .collection(Collections.users)
        .getFullList(
          filter: _pb.filter('association = {:a}', {'a': _assocId}),
          sort: 'name',
        );
    return records.map((r) => UsersRecord.fromJson(r.toJson())).toList();
  }

  Future<GeneralMeeting?> getMeeting(String id) async {
    try {
      final r = await _pb
          .collection(GeneralMeetingCollections.meetings)
          .getOne(id);
      return GeneralMeeting.fromJson(r.toJson());
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching meeting: $e');
      return null;
    }
  }

  Future<List<GeneralMeetingItem>> getItems(String meetingId) async {
    try {
      final records = await _pb
          .collection(GeneralMeetingCollections.items)
          .getFullList(
            filter: _pb.filter('general_meeting = {:m}', {'m': meetingId}),
            sort: 'sort_order,created',
          );
      return records
          .map((r) => GeneralMeetingItem.fromJson(r.toJson()))
          .toList();
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching agenda: $e');
      return [];
    }
  }

  // --- Motioner

  /// Egna motioner (även utkast) och andras inlämnade — API-reglerna
  /// bestämmer vad som syns.
  Future<List<Motion>> getMotions(String meetingId) async {
    try {
      final records = await _pb
          .collection(GeneralMeetingCollections.motions)
          .getFullList(
            filter: _pb.filter('general_meeting = {:m}', {'m': meetingId}),
            sort: '-created',
            expand: 'submitted_by,residence',
          );
      return records.map((r) => Motion.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching motions: $e');
      return [];
    }
  }

  /// Skapar eller uppdaterar ett eget motionsutkast. [submit] lämnar in det.
  /// Kastar vid fel.
  Future<void> saveMotion({
    String? motionId,
    required String meetingId,
    required String title,
    required String text,
    required bool submit,
    String residenceId = '',
    List<PlatformFile> newAttachments = const [],
    List<String> removedAttachments = const [],
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'text': text,
      'status': submit ? 'inlämnad' : 'utkast',
      'residence': residenceId,
      // `attachments-` tar bort de namngivna filerna från ett eget utkast.
      if (removedAttachments.isNotEmpty) 'attachments-': removedAttachments,
    };
    final files = <http.MultipartFile>[
      for (final f in newAttachments)
        if (f.bytes != null)
          http.MultipartFile.fromBytes(
            // `attachments+` lägger till filer i stället för att ersätta dem.
            motionId == null ? 'attachments' : 'attachments+',
            f.bytes!,
            filename: f.name,
          ),
    ];

    final collection = _pb.collection(GeneralMeetingCollections.motions);
    if (motionId == null) {
      body.addAll({
        'association': _assocId,
        'general_meeting': meetingId,
        'submitted_by': currentUserId,
      });
      await collection.create(body: body, files: files);
    } else {
      await collection.update(motionId, body: body, files: files);
    }
  }

  /// Styrelsens yttrande. Ett förslag (bifall/avslag/delvis) gör motionen
  /// besvarad och lägger den som beslutspunkt på dagordningen (servern).
  Future<void> answerMotion(
    String motionId, {
    required String boardResponse,
    required String recommendation,
  }) => _pb
      .collection(GeneralMeetingCollections.motions)
      .update(
        motionId,
        body: {
          'board_response': boardResponse,
          'recommendation': recommendation,
        },
      );

  Future<void> deleteMotion(String motionId) =>
      _pb.collection(GeneralMeetingCollections.motions).delete(motionId);

  String fileUrl(String collectionId, String recordId, String filename) =>
      _pb.buildURL('/api/files/$collectionId/$recordId/$filename').toString();

  // --- Fullmakter

  Future<List<Proxy>> getProxies(String meetingId) async {
    try {
      final records = await _pb
          .collection(GeneralMeetingCollections.proxies)
          .getFullList(
            filter: _pb.filter('general_meeting = {:m}', {'m': meetingId}),
            sort: '-created',
            expand: 'residence,granted_by',
          );
      return records.map((r) => Proxy.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching proxies: $e');
      return [];
    }
  }

  /// Bostäder där den inloggade bor.
  Future<List<ResidencesRecord>> myResidences() async {
    final userId = currentUserId;
    if (userId.isEmpty || _assocId.isEmpty) return [];
    try {
      final records = await _pb
          .collection(Collections.residences)
          .getFullList(
            filter: _pb.filter('association = {:a} && users.id ?= {:u}', {
              'a': _assocId,
              'u': userId,
            }),
            sort: 'street_address',
          );
      return records.map((r) => ResidencesRecord.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching residences: $e');
      return [];
    }
  }

  /// Föreningens användare (möjliga ombud), utan den inloggade.
  Future<List<UsersRecord>> possibleProxyHolders() async {
    if (_assocId.isEmpty) return [];
    try {
      final records = await _pb
          .collection(Collections.users)
          .getFullList(
            filter: _pb.filter('association = {:a} && id != {:u}', {
              'a': _assocId,
              'u': currentUserId,
            }),
            sort: 'name',
          );
      return records.map((r) => UsersRecord.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('GeneralMeetingsStore: Error fetching users: $e');
      return [];
    }
  }

  /// Registrerar en fullmakt (status "väntar" tills styrelsen godkänner).
  /// Ange [proxyUserId] (användare i föreningen) eller [proxyName]. Kastar vid
  /// fel.
  Future<void> createProxy({
    required String meetingId,
    required String residenceId,
    String? proxyUserId,
    String proxyName = '',
    PlatformFile? document,
  }) async {
    final body = <String, dynamic>{
      'association': _assocId,
      'general_meeting': meetingId,
      'residence': residenceId,
      'granted_by': currentUserId,
      'proxy_name': proxyName,
      if (proxyUserId != null && proxyUserId.isNotEmpty)
        'proxy_user': proxyUserId,
    };
    final files = <http.MultipartFile>[
      if (document?.bytes != null)
        http.MultipartFile.fromBytes(
          'document',
          document!.bytes!,
          filename: document.name,
        ),
    ];
    await _pb
        .collection(GeneralMeetingCollections.proxies)
        .create(body: body, files: files);
  }

  /// Styrelsen godkänner, avslår eller ångrar beslutet (väntar). Kastar.
  Future<void> reviewProxy(String proxyId, String status, {String note = ''}) =>
      _pb
          .collection(GeneralMeetingCollections.proxies)
          .update(proxyId, body: {'status': status, 'review_note': note});

  /// Återkallar en egen fullmakt (eller tar bort den, med delete-behörighet).
  Future<void> deleteProxy(String proxyId) =>
      _pb.collection(GeneralMeetingCollections.proxies).delete(proxyId);

  /// Fullmaktsdokumentet är skyddat — länken behöver en kortlivad filtoken.
  Future<Uri> proxyDocumentUrl(Proxy proxy) async {
    final token = await _pb.files.getToken();
    return _pb.buildURL(
      '/api/files/${proxy.collectionId}/${proxy.id}/${proxy.document}',
      {'token': token},
    );
  }

  // --- Omröstning

  Future<VotingOverview> getVoting(String meetingId) async {
    final res = await _pb.send('/api/general-meetings/$meetingId/voting');
    return VotingOverview.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Röstar eller ändrar rösten för [unitKey]. Kastar vid fel.
  Future<void> vote(String itemId, String choice, String unitKey) async {
    await _pb.send(
      '/api/general-meeting-items/$itemId/vote',
      method: 'POST',
      body: {'choice': choice, 'unit_key': unitKey},
    );
  }

  // --- Protokoll

  /// Medlemmar: kastar (404 med meddelande) tills protokollet är justerat.
  /// Styrelsen får alltid utkastet.
  Future<GeneralMeetingProtocol> getProtocol(String meetingId) async {
    final res = await _pb.send('/api/general-meetings/$meetingId/protocol');
    return GeneralMeetingProtocol.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// Sparar besluten per punkt och övriga anteckningar. Kastar.
  Future<GeneralMeetingProtocol> saveProtocol(
    String meetingId, {
    required String notes,
    required Map<String, String> decisions,
  }) async {
    final res = await _pb.send(
      '/api/general-meetings/$meetingId/protocol',
      method: 'PUT',
      body: {
        'notes': notes,
        'items': [
          for (final e in decisions.entries) {'id': e.key, 'decision': e.value},
        ],
      },
    );
    return GeneralMeetingProtocol.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }
}
