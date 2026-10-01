import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException, PocketBase;
import '../../core/models/pocketbase_models.dart';

/// E-signing of board meeting protocols with a one-time email code.
///
/// Everything goes through the custom routes in
/// brf-samlat-pb/pb_hooks/api/signatures.pb.js — the collection is read-only for
/// clients and the code fields are hidden. Mirrors the web `signaturesStore`.
class Signature {
  final String id;
  final String boardMeeting;
  final String user;
  final String role;
  final int sortOrder;
  final String documentTitle;

  /// 'pending' | 'signed'
  final String status;
  final String signerName;
  final String signerEmail;
  final String signedAt;
  final String documentHash;

  const Signature({
    required this.id,
    required this.boardMeeting,
    required this.user,
    required this.role,
    required this.sortOrder,
    required this.documentTitle,
    required this.status,
    required this.signerName,
    required this.signerEmail,
    required this.signedAt,
    required this.documentHash,
  });

  bool get isSigned => status == 'signed';

  String get displayName => signerName.isNotEmpty ? signerName : signerEmail;

  factory Signature.fromJson(Map<String, dynamic> json) => Signature(
    id: json['id'] as String? ?? '',
    boardMeeting: json['board_meeting'] as String? ?? '',
    user: json['user'] as String? ?? '',
    role: json['role'] as String? ?? '',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    documentTitle: json['document_title'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    signerName: json['signer_name'] as String? ?? '',
    signerEmail: json['signer_email'] as String? ?? '',
    signedAt: json['signed_at'] as String? ?? '',
    documentHash: json['document_hash'] as String? ?? '',
  );
}

class SignatureView {
  final Signature signature;
  final bool isSigner;
  final String associationName;
  final String currentDocumentHash;
  final BoardMeetingsRecord meeting;
  final List<Signature> signatures;

  const SignatureView({
    required this.signature,
    required this.isSigner,
    required this.associationName,
    required this.currentDocumentHash,
    required this.meeting,
    required this.signatures,
  });

  factory SignatureView.fromJson(Map<String, dynamic> json) => SignatureView(
    signature: Signature.fromJson(
      Map<String, dynamic>.from(json['signature'] as Map),
    ),
    isSigner: json['is_signer'] as bool? ?? false,
    associationName: json['association_name'] as String? ?? '',
    currentDocumentHash: json['current_document_hash'] as String? ?? '',
    meeting: BoardMeetingsRecord.fromJson(
      Map<String, dynamic>.from(json['meeting'] as Map),
    ),
    signatures: _signatureList(json['signatures']),
  );
}

class MeetingSignatures {
  final String currentDocumentHash;
  final List<Signature> signatures;

  const MeetingSignatures(this.currentDocumentHash, this.signatures);

  bool get isLocked => signatures.any((s) => s.isSigned);
}

class SignerInput {
  final String userId;
  final String role;

  const SignerInput(this.userId, this.role);

  Map<String, dynamic> toJson() => {'userId': userId, 'role': role};
}

List<Signature> _signatureList(dynamic raw) => (raw as List? ?? const [])
    .map((e) => Signature.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();

/// The server's (Swedish) error message when there is one, else [fallback].
String signatureErrorMessage(Object e, [String fallback = 'Något gick fel']) {
  if (e is ClientException) {
    final message = e.response['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return fallback;
}

class SignaturesStore {
  final PocketBase _pb;

  SignaturesStore(this._pb);

  final _mine = ref<List<Signature>>([]);

  /// The signatures the current user has been asked to make.
  Ref<List<Signature>> get mine => _mine;

  int get pendingCount => _mine.value.where((s) => !s.isSigned).length;

  Future<bool> getMine() async {
    try {
      final res = await _pb.send('/api/signatures/mine');
      _mine.value = _signatureList((res as Map)['signatures']);
      return true;
    } catch (e) {
      debugPrint('SignaturesStore: Error fetching my signatures: $e');
      return false;
    }
  }

  Future<MeetingSignatures?> getForMeeting(String meetingId) async {
    try {
      final res = await _pb.send('/api/board-meetings/$meetingId/signatures');
      final map = res as Map;
      return MeetingSignatures(
        map['current_document_hash'] as String? ?? '',
        _signatureList(map['signatures']),
      );
    } catch (e) {
      debugPrint('SignaturesStore: Error fetching meeting signatures: $e');
      return null;
    }
  }

  /// Throws [ClientException]; use [signatureErrorMessage] for the UI.
  Future<List<Signature>> createRequest(
    String meetingId,
    List<SignerInput> signers,
  ) async {
    final res = await _pb.send(
      '/api/board-meetings/$meetingId/signatures',
      method: 'POST',
      body: {'signers': signers.map((s) => s.toJson()).toList()},
    );
    return _signatureList((res as Map)['signatures']);
  }

  Future<void> cancelRequest(String meetingId) async {
    await _pb.send(
      '/api/board-meetings/$meetingId/signatures',
      method: 'DELETE',
    );
  }

  Future<SignatureView> view(String signatureId) async {
    final res = await _pb.send('/api/signatures/$signatureId');
    return SignatureView.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Returns the email address the code was sent to.
  Future<String> requestCode(String signatureId) async {
    final res = await _pb.send(
      '/api/signatures/$signatureId/request-code',
      method: 'POST',
    );
    return (res as Map)['email'] as String? ?? '';
  }

  Future<Signature> sign(String signatureId, String code) async {
    final res = await _pb.send(
      '/api/signatures/$signatureId/sign',
      method: 'POST',
      body: {'code': code},
    );
    final signed = Signature.fromJson(
      Map<String, dynamic>.from((res as Map)['signature'] as Map),
    );
    _mine.value = [for (final s in _mine.value) s.id == signed.id ? signed : s];
    return signed;
  }
}
