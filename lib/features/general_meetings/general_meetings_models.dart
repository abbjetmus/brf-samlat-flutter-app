import 'package:intl/intl.dart';
import '../../core/utils/pb_error.dart';

/// Föreningsstämma — modeller för samlingarna general_meetings,
/// general_meeting_items, motions och proxies samt svaren från
/// /api/general-meetings/{id}/voting och /protocol
/// (brf-samlat-pb/pb_hooks/utils/general_meeting_utils.js).

class GeneralMeetingCollections {
  static const String meetings = 'general_meetings';
  static const String items = 'general_meeting_items';
  static const String motions = 'motions';
  static const String proxies = 'proxies';
  static const String voters = 'general_meeting_voters';
}

/// Statusvärden som de lagras i PocketBase.
class GeneralMeetingStatus {
  static const String draft = 'utkast';
  static const String called = 'kallad';
  static const String ongoing = 'pågår';
  static const String closed = 'avslutad';
}

class VoteStatus {
  static const String none = 'ej_öppnad';
  static const String open = 'öppen';
  static const String closed = 'stängd';
}

const voteChoices = <(String, String)>[
  ('ja', 'Ja'),
  ('nej', 'Nej'),
  ('avstår', 'Avstår'),
];

String _s(dynamic v) => v is String ? v : '';
bool _b(dynamic v) => v is bool ? v : false;
int _i(dynamic v) => v is num ? v.toInt() : 0;
List<String> _list(dynamic v) =>
    v is List ? v.whereType<String>().toList() : const [];
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

/// PocketBase-datum ("2026-11-20 17:00:00.000Z") i svensk lokal tid.
DateTime? parsePbDate(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// "fredag 20 november 2026 kl. 18.00"
String formatMeetingDateTime(String value) {
  final d = parsePbDate(value);
  if (d == null) return '';
  return DateFormat("EEEE d MMMM yyyy 'kl.' HH.mm", 'sv_SE').format(d);
}

/// "20 november 2026"
String formatMeetingDate(String value) {
  final d = parsePbDate(value);
  if (d == null) return '';
  return DateFormat('d MMMM yyyy', 'sv_SE').format(d);
}

/// Serverns (svenska) felmeddelande när det finns, annars [fallback].
/// Se [pbErrorMessage].
String generalMeetingErrorMessage(
  Object e, [
  String fallback = 'Något gick fel',
]) => pbErrorMessage(e, fallback);

const meetingTypeLabels = <String, String>{
  'ordinarie': 'Ordinarie föreningsstämma',
  'extra': 'Extra föreningsstämma',
};

/// Styrelsens etikett för status (medlemmar ser [GeneralMeeting.statusLabel]).
const meetingStatusLabels = <String, String>{
  GeneralMeetingStatus.draft: 'Utkast',
  GeneralMeetingStatus.called: 'Kallad',
  GeneralMeetingStatus.ongoing: 'Pågår',
  GeneralMeetingStatus.closed: 'Avslutad',
};

const motionRecommendations = <(String, String)>[
  ('bifall', 'Bifall'),
  ('avslag', 'Avslag'),
  ('delvis', 'Delvis bifall'),
];

const legalNote =
    'Digitalt deltagande på stämman förutsätter att föreningens stadgar '
    'tillåter det (lagen om ekonomiska föreningar).';

/// Lokal tid -> UTC-sträng för PocketBase ('' = tomt).
String toPbDate(DateTime? value) =>
    value == null ? '' : value.toUtc().toIso8601String();

class GeneralMeeting {
  final String id;
  final String association;
  final String title;

  /// 'ordinarie' | 'extra'
  final String type;
  final String startAt;
  final String location;
  final bool digital;
  final String digitalInfo;
  final String description;

  /// utkast | kallad | pågår | avslutad
  final String status;

  /// per_residence | per_member
  final String voteMode;
  final String noticeSentAt;
  final String motionDeadline;
  final bool motionsOpen;
  final bool votingOpen;

  const GeneralMeeting({
    required this.id,
    required this.association,
    required this.title,
    required this.type,
    required this.startAt,
    required this.location,
    required this.digital,
    required this.digitalInfo,
    required this.description,
    required this.status,
    required this.voteMode,
    required this.noticeSentAt,
    required this.motionDeadline,
    required this.motionsOpen,
    required this.votingOpen,
  });

  factory GeneralMeeting.fromJson(Map<String, dynamic> json) => GeneralMeeting(
    id: _s(json['id']),
    association: _s(json['association']),
    title: _s(json['title']),
    type: _s(json['type']),
    startAt: _s(json['start_at']),
    location: _s(json['location']),
    digital: _b(json['digital']),
    digitalInfo: _s(json['digital_info']),
    description: _s(json['description']),
    status: _s(json['status']),
    voteMode: _s(json['vote_mode']).isEmpty
        ? 'per_residence'
        : _s(json['vote_mode']),
    noticeSentAt: _s(json['notice_sent_at']),
    motionDeadline: _s(json['motion_deadline']),
    motionsOpen: _b(json['motions_open']),
    votingOpen: _b(json['voting_open']),
  );

  String get typeLabel =>
      type == 'extra' ? 'Extra föreningsstämma' : 'Ordinarie föreningsstämma';

  /// Etikett för medlemmar. Ett utkast syns bara när styrelsen tar emot
  /// motioner, så det är det medlemmen ska se.
  String get statusLabel => switch (status) {
    GeneralMeetingStatus.draft => 'Tar emot motioner',
    GeneralMeetingStatus.called => 'Kallad',
    GeneralMeetingStatus.ongoing => 'Pågår',
    GeneralMeetingStatus.closed => 'Avslutad',
    _ => status,
  };

  bool get isUpcoming {
    final d = parsePbDate(startAt);
    return status != GeneralMeetingStatus.closed &&
        (d == null ||
            d.isAfter(DateTime.now().subtract(const Duration(days: 1))));
  }

  /// Samma villkor som servern (motionWindowOpen) så knappen bara visas när
  /// en inlämning kan lyckas.
  bool get canSubmitMotions {
    if (status != GeneralMeetingStatus.draft &&
        status != GeneralMeetingStatus.called) {
      return false;
    }
    if (!motionsOpen) return false;
    final deadline = parsePbDate(motionDeadline);
    return deadline == null || DateTime.now().isBefore(deadline);
  }

  /// Fullmakter registreras när stämman är kallad eller pågår.
  bool get canRegisterProxies =>
      status == GeneralMeetingStatus.called ||
      status == GeneralMeetingStatus.ongoing;
}

class GeneralMeetingItem {
  final String id;
  final String generalMeeting;
  final int sortOrder;
  final String title;
  final String description;
  final bool isDecision;
  final String voteStatus;
  final String motion;

  const GeneralMeetingItem({
    required this.id,
    required this.generalMeeting,
    required this.sortOrder,
    required this.title,
    required this.description,
    required this.isDecision,
    required this.voteStatus,
    required this.motion,
  });

  /// En punkt vars omröstning har öppnats måste förbli en beslutspunkt.
  bool get voteStarted => voteStatus != VoteStatus.none;

  factory GeneralMeetingItem.fromJson(Map<String, dynamic> json) =>
      GeneralMeetingItem(
        id: _s(json['id']),
        generalMeeting: _s(json['general_meeting']),
        sortOrder: _i(json['sort_order']),
        title: _s(json['title']),
        description: _s(json['description']),
        isDecision: _b(json['is_decision']),
        voteStatus: _s(json['vote_status']).isEmpty
            ? VoteStatus.none
            : _s(json['vote_status']),
        motion: _s(json['motion']),
      );
}

class Motion {
  final String id;
  final String collectionId;
  final String generalMeeting;
  final String title;
  final String text;
  final List<String> attachments;
  final String submittedBy;
  final String submittedByName;
  final String residence;
  final String residenceLabel;

  /// utkast | inlämnad | besvarad
  final String status;
  final String submittedAt;
  final String boardResponse;

  /// bifall | avslag | delvis
  final String recommendation;
  final String agendaItem;

  const Motion({
    required this.id,
    required this.collectionId,
    required this.generalMeeting,
    required this.title,
    required this.text,
    required this.attachments,
    required this.submittedBy,
    required this.submittedByName,
    required this.residence,
    this.residenceLabel = '',
    required this.status,
    required this.submittedAt,
    required this.boardResponse,
    required this.recommendation,
    required this.agendaItem,
  });

  factory Motion.fromJson(Map<String, dynamic> json) {
    final expand = _map(json['expand']);
    final author = _map(expand['submitted_by']);
    return Motion(
      id: _s(json['id']),
      collectionId: _s(json['collectionId']),
      generalMeeting: _s(json['general_meeting']),
      title: _s(json['title']),
      text: _s(json['text']),
      attachments: _list(json['attachments']),
      submittedBy: _s(json['submitted_by']),
      submittedByName: _s(author['name']),
      residence: _s(json['residence']),
      residenceLabel: _s(_map(expand['residence'])['street_address']),
      status: _s(json['status']),
      submittedAt: _s(json['submitted_at']),
      boardResponse: _s(json['board_response']),
      recommendation: _s(json['recommendation']),
      agendaItem: _s(json['agenda_item']),
    );
  }

  bool get isDraft => status == 'utkast';

  String get statusLabel => switch (status) {
    'utkast' => 'Utkast',
    'inlämnad' => 'Inlämnad',
    'besvarad' => 'Besvarad',
    _ => status,
  };

  String get recommendationLabel => switch (recommendation) {
    'bifall' => 'Styrelsen föreslår bifall',
    'avslag' => 'Styrelsen föreslår avslag',
    'delvis' => 'Styrelsen föreslår delvis bifall',
    _ => '',
  };
}

class Proxy {
  final String id;
  final String collectionId;
  final String generalMeeting;
  final String residence;
  final String residenceLabel;
  final String grantedBy;
  final String grantedByName;
  final String proxyUser;
  final String proxyName;
  final String document;

  /// väntar | godkänd | avslagen
  final String status;
  final String reviewNote;

  const Proxy({
    required this.id,
    required this.collectionId,
    required this.generalMeeting,
    required this.residence,
    required this.residenceLabel,
    required this.grantedBy,
    required this.grantedByName,
    required this.proxyUser,
    required this.proxyName,
    required this.document,
    required this.status,
    required this.reviewNote,
  });

  factory Proxy.fromJson(Map<String, dynamic> json) {
    final expand = _map(json['expand']);
    return Proxy(
      id: _s(json['id']),
      collectionId: _s(json['collectionId']),
      generalMeeting: _s(json['general_meeting']),
      residence: _s(json['residence']),
      residenceLabel: _s(_map(expand['residence'])['street_address']),
      grantedBy: _s(json['granted_by']),
      grantedByName: _s(_map(expand['granted_by'])['name']),
      proxyUser: _s(json['proxy_user']),
      proxyName: _s(json['proxy_name']),
      document: _s(json['document']),
      status: _s(json['status']),
      reviewNote: _s(json['review_note']),
    );
  }

  String get statusLabel => switch (status) {
    'väntar' => 'Väntar på godkännande',
    'godkänd' => 'Godkänd',
    'avslagen' => 'Ej godkänd',
    _ => status,
  };
}

class VoteCounts {
  final int ja;
  final int nej;
  final int avstar;

  const VoteCounts(this.ja, this.nej, this.avstar);

  factory VoteCounts.fromJson(dynamic raw) {
    final m = _map(raw);
    return VoteCounts(_i(m['ja']), _i(m['nej']), _i(m['avstår']));
  }

  int get total => ja + nej + avstar;
}

class VoteResults {
  final VoteCounts digital;
  final VoteCounts manual;
  final VoteCounts total;
  final int votesCast;

  const VoteResults({
    required this.digital,
    required this.manual,
    required this.total,
    required this.votesCast,
  });

  static VoteResults? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return VoteResults(
      digital: VoteCounts.fromJson(m['digital']),
      manual: VoteCounts.fromJson(m['manual']),
      total: VoteCounts.fromJson(m['total']),
      votesCast: _i(m['votes_cast']),
    );
  }
}

/// En röst den inloggade får lägga: den egna bostaden (eller sig själv vid
/// per_member) eller en godkänd fullmakt.
class VotingUnit {
  final String unitKey;
  final String residence;
  final String proxy;
  final String label;
  final bool own;
  final String blockedReason;

  const VotingUnit({
    required this.unitKey,
    required this.residence,
    required this.proxy,
    required this.label,
    required this.own,
    required this.blockedReason,
  });

  factory VotingUnit.fromJson(Map<String, dynamic> json) => VotingUnit(
    unitKey: _s(json['unit_key']),
    residence: _s(json['residence']),
    proxy: _s(json['proxy']),
    label: _s(json['label']),
    own: _b(json['own']),
    blockedReason: _s(json['blocked_reason']),
  );

  bool get blocked => blockedReason.isNotEmpty;
}

class VotingItem {
  final String id;
  final String title;
  final String description;
  final int sortOrder;
  final String voteStatus;
  final String motion;
  final VoteResults? results;

  /// unit_key -> choice
  final Map<String, String> myVotes;

  const VotingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.voteStatus,
    this.motion = '',
    required this.results,
    required this.myVotes,
  });

  factory VotingItem.fromJson(Map<String, dynamic> json) => VotingItem(
    id: _s(json['id']),
    title: _s(json['title']),
    description: _s(json['description']),
    sortOrder: _i(json['sort_order']),
    voteStatus: _s(json['vote_status']).isEmpty
        ? VoteStatus.none
        : _s(json['vote_status']),
    motion: _s(json['motion']),
    results: VoteResults.fromJson(json['results']),
    myVotes: _map(
      json['my_votes'],
    ).map((k, v) => MapEntry(k, v is String ? v : '')),
  );
}

class VotingOverview {
  final String status;
  final bool votingOpen;
  final String voteMode;

  /// Styrelsen: ser löpande siffror och leder omröstningarna.
  final bool canManage;
  final int registerTotal;
  final int registerWithVote;
  final int registerPresent;
  final List<VotingUnit> units;
  final List<VotingItem> items;

  const VotingOverview({
    required this.status,
    required this.votingOpen,
    required this.voteMode,
    this.canManage = false,
    this.registerTotal = 0,
    this.registerWithVote = 0,
    this.registerPresent = 0,
    required this.units,
    required this.items,
  });

  factory VotingOverview.fromJson(Map<String, dynamic> json) {
    final meeting = _map(json['meeting']);
    final register = _map(json['register']);
    return VotingOverview(
      status: _s(meeting['status']),
      votingOpen: _b(meeting['voting_open']),
      voteMode: _s(meeting['vote_mode']),
      canManage: _b(json['can_manage']),
      registerTotal: _i(register['total']),
      registerWithVote: _i(register['with_vote']),
      registerPresent: _i(register['present']),
      units: (json['units'] as List? ?? const [])
          .map((e) => VotingUnit.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      items: (json['items'] as List? ?? const [])
          .map((e) => VotingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ProtocolItem {
  final String id;
  final String title;
  final String description;
  final bool isDecision;
  final String decision;
  final VoteResults? results;

  const ProtocolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isDecision,
    required this.decision,
    required this.results,
  });

  factory ProtocolItem.fromJson(Map<String, dynamic> json) => ProtocolItem(
    id: _s(json['id']),
    title: _s(json['title']),
    description: _s(json['description']),
    isDecision: _b(json['is_decision']),
    decision: _s(json['decision']),
    results: VoteResults.fromJson(json['results']),
  );
}

class ProtocolSigner {
  final String name;
  final String role;
  final String status;
  final String signedAt;

  const ProtocolSigner(this.name, this.role, this.status, this.signedAt);

  factory ProtocolSigner.fromJson(Map<String, dynamic> json) {
    final name = _s(json['signer_name']);
    return ProtocolSigner(
      name.isNotEmpty ? name : _s(json['signer_email']),
      _s(json['role']),
      _s(json['status']),
      _s(json['signed_at']),
    );
  }

  bool get isSigned => status == 'signed';
}

class GeneralMeetingProtocol {
  final String notes;
  final List<ProtocolItem> items;
  final List<ProtocolSigner> signatures;
  final String documentHash;
  final bool complete;

  /// Minst en signatur — protokollet kan inte längre ändras.
  final bool locked;
  final String location;

  const GeneralMeetingProtocol({
    required this.notes,
    required this.items,
    required this.signatures,
    required this.documentHash,
    required this.complete,
    this.locked = false,
    this.location = '',
  });

  factory GeneralMeetingProtocol.fromJson(Map<String, dynamic> json) =>
      GeneralMeetingProtocol(
        notes: _s(json['notes']),
        locked: _b(json['locked']),
        location: _s(_map(json['meeting'])['location']),
        items: (json['items'] as List? ?? const [])
            .map(
              (e) => ProtocolItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        signatures: (json['signatures'] as List? ?? const [])
            .map(
              (e) =>
                  ProtocolSigner.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        documentHash: _s(json['current_document_hash']),
        complete: _b(json['complete']),
      );
}

/// Ett resultat som "Ja 12 · Nej 3 · Avstår 1".
String resultLine(VoteCounts c) =>
    'Ja ${c.ja} · Nej ${c.nej} · Avstår ${c.avstar}';

/// Föreningens stämmoinställningar (GET/PUT /api/general-meeting-settings).
class GeneralMeetingSettings {
  final String voteMode;
  final int noticeMinWeeks;
  final int noticeMaxWeeks;
  final int maxProxiesPerHolder;

  const GeneralMeetingSettings({
    this.voteMode = 'per_residence',
    this.noticeMinWeeks = 2,
    this.noticeMaxWeeks = 6,
    this.maxProxiesPerHolder = 1,
  });

  factory GeneralMeetingSettings.fromJson(Map<String, dynamic> json) =>
      GeneralMeetingSettings(
        voteMode: _s(json['vote_mode']).isEmpty
            ? 'per_residence'
            : _s(json['vote_mode']),
        noticeMinWeeks: _i(json['notice_min_weeks']),
        noticeMaxWeeks: _i(json['notice_max_weeks']),
        maxProxiesPerHolder: _i(json['max_proxies_per_holder']),
      );

  Map<String, dynamic> toJson() => {
    'vote_mode': voteMode,
    'notice_min_weeks': noticeMinWeeks,
    'notice_max_weeks': noticeMaxWeeks,
    'max_proxies_per_holder': maxProxiesPerHolder,
  };
}

/// Kontroll av kallelsetiden (GET /api/general-meetings/{id}/notice-check).
class NoticeCheck {
  final bool ok;

  /// Kan inte skickas alls (datum saknas eller har passerat).
  final bool blocking;
  final String message;

  const NoticeCheck({
    required this.ok,
    required this.blocking,
    required this.message,
  });

  factory NoticeCheck.fromJson(Map<String, dynamic> json) => NoticeCheck(
    ok: _b(json['ok']),
    blocking: _b(json['blocking']),
    message: _s(json['message']),
  );
}

/// En rad i röstlängden (general_meeting_voters).
class GeneralMeetingVoter {
  final String id;
  final String unitKey;
  final String label;
  final bool hasVote;
  final bool present;
  final String note;

  const GeneralMeetingVoter({
    required this.id,
    required this.unitKey,
    required this.label,
    required this.hasVote,
    required this.present,
    required this.note,
  });

  factory GeneralMeetingVoter.fromJson(Map<String, dynamic> json) =>
      GeneralMeetingVoter(
        id: _s(json['id']),
        unitKey: _s(json['unit_key']),
        label: _s(json['label']),
        hasVote: _b(json['has_vote']),
        present: _b(json['present']),
        note: _s(json['note']),
      );
}
