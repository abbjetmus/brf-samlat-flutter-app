// Collection names matching PocketBase
class Collections {
  static const String associations = 'associations';
  static const String associationRoleTypes = 'association_role_types';
  static const String boardMeetingTemplates = 'board_meeting_templates';
  static const String boardMeetings = 'board_meetings';
  static const String calendarEvents = 'calendar_events';
  static const String faq = 'faq';
  static const String foldersAndFiles = 'folders_and_files';
  static const String formResponses = 'form_responses';
  static const String forms = 'forms';
  static const String gadgetBookings = 'gadget_bookings';
  static const String gadgets = 'gadgets';
  static const String invoiceTemplates = 'invoice_templates';
  static const String invoices = 'invoices';
  static const String issueComments = 'issue_comments';
  static const String issues = 'issues';
  static const String issuesView = 'issues_view';
  static const String parkingLots = 'parking_lots';
  static const String parkingSpaces = 'parking_spaces';
  static const String placeBookings = 'place_bookings';
  static const String places = 'places';
  static const String postComments = 'post_comments';
  static const String posts = 'posts';
  static const String postsView = 'posts_view';
  static const String residences = 'residences';
  static const String settings = 'settings';
  static const String systemBoardMeetingTemplates =
      'system_board_meeting_templates';
  static const String userInvitations = 'user_invitations';
  static const String userNotifications = 'user_notifications';
  static const String userNotificationsNotSeenCountView =
      'user_notifications_not_seen_count_view';
  static const String userRoleTypes = 'user_role_types';
  static const String userSettings = 'user_settings';
  static const String users = 'users';
  static const String chatRooms = 'chat_rooms';
  static const String chatMessages = 'chat_messages';
  static const String chatReadReceipts = 'chat_read_receipts';
}

// --- Users ---

class UsersRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String? email;
  final bool? emailVisibility;
  final String? avatar;
  final String? phone;
  final String association;
  final String userRoleType;
  final List<String> associationRoleTypes;
  final bool? verified;

  UsersRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.email,
    this.emailVisibility,
    this.avatar,
    this.phone,
    required this.association,
    required this.userRoleType,
    this.associationRoleTypes = const [],
    this.verified,
  });

  factory UsersRecord.fromJson(Map<String, dynamic> json) {
    return UsersRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      emailVisibility: json['emailVisibility'] as bool?,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      association: json['association'] as String? ?? '',
      userRoleType: json['user_role_type'] as String? ?? '',
      associationRoleTypes:
          (json['association_role_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      verified: json['verified'] as bool?,
    );
  }

  UsersRecord copyWith({
    String? id,
    String? created,
    String? updated,
    String? name,
    String? email,
    bool? emailVisibility,
    String? avatar,
    String? phone,
    String? association,
    String? userRoleType,
    List<String>? associationRoleTypes,
    bool? verified,
  }) {
    return UsersRecord(
      id: id ?? this.id,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVisibility: emailVisibility ?? this.emailVisibility,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      association: association ?? this.association,
      userRoleType: userRoleType ?? this.userRoleType,
      associationRoleTypes: associationRoleTypes ?? this.associationRoleTypes,
      verified: verified ?? this.verified,
    );
  }
}

// --- Associations ---

class AssociationsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String associationType;
  final String organizationNumber;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final String? email;
  final List<dynamic>? permissions;

  /// Feature tokens this association has switched off (denylist). Empty = all on.
  final List<String> disabledFeatures;

  AssociationsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.associationType,
    required this.organizationNumber,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    this.email,
    this.permissions,
    this.disabledFeatures = const [],
  });

  factory AssociationsRecord.fromJson(Map<String, dynamic> json) {
    return AssociationsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      associationType: json['association_type'] as String? ?? '',
      organizationNumber: json['organization_number'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      email: json['email'] as String?,
      permissions: json['permissions'] as List<dynamic>?,
      disabledFeatures: (json['disabled_features'] is List)
          ? (json['disabled_features'] as List)
                .map((e) => e.toString())
                .toList()
          : const [],
    );
  }
}

// --- Role Types ---

class UserRoleTypesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String displayName;

  UserRoleTypesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.displayName = '',
  });

  factory UserRoleTypesRecord.fromJson(Map<String, dynamic> json) {
    return UserRoleTypesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }
}

class AssociationRoleTypesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String displayName;

  AssociationRoleTypesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.displayName = '',
  });

  factory AssociationRoleTypesRecord.fromJson(Map<String, dynamic> json) {
    return AssociationRoleTypesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }
}

// --- Posts ---

class PostsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String description;
  final String association;
  final String? user;
  final List<String> attachments;
  final bool commentsAllowed;
  final bool pinAsGeneralInfo;
  final bool addToCalendar;
  final String? startAt;
  final String? endAt;
  final bool? sendPushNotification;

  PostsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    required this.description,
    required this.association,
    this.user,
    this.attachments = const [],
    this.commentsAllowed = true,
    this.pinAsGeneralInfo = false,
    this.addToCalendar = false,
    this.startAt,
    this.endAt,
    this.sendPushNotification,
  });

  factory PostsRecord.fromJson(Map<String, dynamic> json) {
    return PostsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      association: json['association'] as String? ?? '',
      user: json['user'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      commentsAllowed: json['comments_allowed'] as bool? ?? true,
      pinAsGeneralInfo: json['pin_as_general_info'] as bool? ?? false,
      addToCalendar: json['add_to_calendar'] as bool? ?? false,
      startAt: json['start_at'] as String?,
      endAt: json['end_at'] as String?,
      sendPushNotification: json['send_push_notification'] as bool?,
    );
  }
}

class PostsViewRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String description;
  final String association;
  final bool commentsAllowed;
  final int commentsCount;
  final bool pinAsGeneralInfo;

  PostsViewRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    required this.description,
    required this.association,
    this.commentsAllowed = true,
    this.commentsCount = 0,
    this.pinAsGeneralInfo = false,
  });

  factory PostsViewRecord.fromJson(Map<String, dynamic> json) {
    return PostsViewRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      association: json['association'] as String? ?? '',
      commentsAllowed: json['comments_allowed'] as bool? ?? true,
      commentsCount: json['comments_count'] as int? ?? 0,
      pinAsGeneralInfo: json['pin_as_general_info'] as bool? ?? false,
    );
  }
}

class PostCommentsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String comment;
  final String post;
  final String? user;
  final Map<String, dynamic>? expand;

  PostCommentsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.comment,
    required this.post,
    this.user,
    this.expand,
  });

  factory PostCommentsRecord.fromJson(Map<String, dynamic> json) {
    return PostCommentsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      comment: json['comment'] as String? ?? '',
      post: json['post'] as String? ?? '',
      user: json['user'] as String?,
      expand: json['expand'] as Map<String, dynamic>?,
    );
  }
}

// --- Issues ---

class IssuesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String description;
  final String association;
  // "Felanmälan" (defect report) or "Ärende" (case). Null on legacy rows.
  final String? type;
  final String? assignedTo;
  final String? reportedBy;
  final String? residence;
  final List<String> attachments;
  final bool commentsAllowed;
  final bool isResolved;
  final String? resolvedAt;
  final bool? consentToMasterKey;
  final bool? sendPushNotification;

  IssuesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    required this.description,
    required this.association,
    this.type,
    this.assignedTo,
    this.reportedBy,
    this.residence,
    this.attachments = const [],
    this.commentsAllowed = true,
    this.isResolved = false,
    this.resolvedAt,
    this.consentToMasterKey,
    this.sendPushNotification,
  });

  factory IssuesRecord.fromJson(Map<String, dynamic> json) {
    return IssuesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      association: json['association'] as String? ?? '',
      type: json['type'] as String?,
      assignedTo: json['assigned_to'] as String?,
      reportedBy: json['reported_by'] as String?,
      residence: json['residence'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      commentsAllowed: json['comments_allowed'] as bool? ?? true,
      isResolved: json['is_resolved'] as bool? ?? false,
      resolvedAt: json['resolved_at'] as String?,
      consentToMasterKey: json['consent_to_master_key'] as bool?,
      sendPushNotification: json['send_push_notification'] as bool?,
    );
  }
}

class IssuesViewRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String description;
  final String association;
  final String? type;
  final bool isResolved;
  final int commentCount;
  final bool commentsAllowed;
  final String? residence;

  IssuesViewRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    required this.description,
    required this.association,
    this.type,
    this.isResolved = false,
    this.commentCount = 0,
    this.commentsAllowed = true,
    this.residence,
  });

  factory IssuesViewRecord.fromJson(Map<String, dynamic> json) {
    return IssuesViewRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      association: json['association'] as String? ?? '',
      type: json['type'] as String?,
      isResolved: json['is_resolved'] as bool? ?? false,
      commentCount: json['comment_count'] as int? ?? 0,
      commentsAllowed: json['comments_allowed'] as bool? ?? true,
      residence: json['residence'] as String?,
    );
  }
}

class IssueCommentsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String comment;
  final String issue;
  final String? user;
  final Map<String, dynamic>? expand;

  IssueCommentsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.comment,
    required this.issue,
    this.user,
    this.expand,
  });

  factory IssueCommentsRecord.fromJson(Map<String, dynamic> json) {
    return IssueCommentsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      comment: json['comment'] as String? ?? '',
      issue: json['issue'] as String? ?? '',
      user: json['user'] as String?,
      expand: json['expand'] as Map<String, dynamic>?,
    );
  }
}

// --- Calendar Events ---

class CalendarEventsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String? description;
  final String association;
  final String startAt;
  final String endAt;
  final String color;
  final String? eventType;
  final List<String> attachments;
  final String? user;
  final bool? sendPushNotification;

  CalendarEventsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    this.description,
    required this.association,
    required this.startAt,
    required this.endAt,
    required this.color,
    this.eventType,
    this.attachments = const [],
    this.user,
    this.sendPushNotification,
  });

  factory CalendarEventsRecord.fromJson(Map<String, dynamic> json) {
    return CalendarEventsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      association: json['association'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      color: json['color'] as String? ?? '#2196F3',
      eventType: json['event_type'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      user: json['user'] as String?,
      sendPushNotification: json['send_push_notification'] as bool?,
    );
  }
}

// --- Places ---

class PlacesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String? description;
  final String association;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final List<String> images;
  final String? placeType;
  final String bookingStartTime;
  final String bookingEndTime;
  final int bookingSlotDurationLength;
  final String bookingSlotDurationType;
  final int? maxRoomCapacity;
  final double? pricePerSlot;
  final String? allowedBookingPeriodType;
  final int? allowedNumberOfBookingsPerPeriod;
  final String user;

  PlacesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.description,
    required this.association,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    this.images = const [],
    this.placeType,
    required this.bookingStartTime,
    required this.bookingEndTime,
    required this.bookingSlotDurationLength,
    required this.bookingSlotDurationType,
    this.maxRoomCapacity,
    this.pricePerSlot,
    this.allowedBookingPeriodType,
    this.allowedNumberOfBookingsPerPeriod,
    required this.user,
  });

  factory PlacesRecord.fromJson(Map<String, dynamic> json) {
    return PlacesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      association: json['association'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      placeType: json['place_type'] as String?,
      bookingStartTime: json['booking_start_time'] as String? ?? '',
      bookingEndTime: json['booking_end_time'] as String? ?? '',
      bookingSlotDurationLength:
          json['booking_slot_duration_length'] as int? ?? 0,
      bookingSlotDurationType:
          json['booking_slot_duration_type'] as String? ?? '',
      maxRoomCapacity: json['max_room_capacity'] as int?,
      pricePerSlot: (json['price_per_slot'] as num?)?.toDouble(),
      allowedBookingPeriodType: json['allowed_booking_period_type'] as String?,
      allowedNumberOfBookingsPerPeriod:
          json['allowed_number_of_bookings_per_period'] as int?,
      user: json['user'] as String? ?? '',
    );
  }
}

class PlaceBookingsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String place;
  final String residence;
  final String startAt;
  final String endAt;
  final String? title;
  final String? description;
  final bool isAllDay;
  final bool isBlock;
  final String? user;

  PlaceBookingsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.place,
    required this.residence,
    required this.startAt,
    required this.endAt,
    this.title,
    this.description,
    this.isAllDay = false,
    this.isBlock = false,
    this.user,
  });

  factory PlaceBookingsRecord.fromJson(Map<String, dynamic> json) {
    return PlaceBookingsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      place: json['place'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      isAllDay: json['is_all_day'] as bool? ?? false,
      isBlock: json['is_block'] as bool? ?? false,
      user: json['user'] as String?,
    );
  }
}

// --- Gadgets ---

class GadgetsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String? description;
  final String association;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final List<String> images;
  final String bookingStartTime;
  final String bookingEndTime;
  final int bookingSlotDurationLength;
  final String bookingSlotDurationType;
  final double? pricePerSlot;
  final String? allowedBookingPeriodType;
  final int? allowedNumberOfBookingsPerPeriod;
  final String user;

  GadgetsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.description,
    required this.association,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    this.images = const [],
    required this.bookingStartTime,
    required this.bookingEndTime,
    required this.bookingSlotDurationLength,
    required this.bookingSlotDurationType,
    this.pricePerSlot,
    this.allowedBookingPeriodType,
    this.allowedNumberOfBookingsPerPeriod,
    required this.user,
  });

  factory GadgetsRecord.fromJson(Map<String, dynamic> json) {
    return GadgetsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      association: json['association'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      bookingStartTime: json['booking_start_time'] as String? ?? '',
      bookingEndTime: json['booking_end_time'] as String? ?? '',
      bookingSlotDurationLength:
          json['booking_slot_duration_length'] as int? ?? 0,
      bookingSlotDurationType:
          json['booking_slot_duration_type'] as String? ?? '',
      pricePerSlot: (json['price_per_slot'] as num?)?.toDouble(),
      allowedBookingPeriodType: json['allowed_booking_period_type'] as String?,
      allowedNumberOfBookingsPerPeriod:
          json['allowed_number_of_bookings_per_period'] as int?,
      user: json['user'] as String? ?? '',
    );
  }
}

class GadgetBookingsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String gadget;
  final String residence;
  final String startAt;
  final String endAt;
  final String? title;
  final String? description;
  final bool isAllDay;
  final bool isBlock;
  final String? user;

  GadgetBookingsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.gadget,
    required this.residence,
    required this.startAt,
    required this.endAt,
    this.title,
    this.description,
    this.isAllDay = false,
    this.isBlock = false,
    this.user,
  });

  factory GadgetBookingsRecord.fromJson(Map<String, dynamic> json) {
    return GadgetBookingsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      gadget: json['gadget'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      isAllDay: json['is_all_day'] as bool? ?? false,
      isBlock: json['is_block'] as bool? ?? false,
      user: json['user'] as String?,
    );
  }
}

// --- Residences ---

class ResidencesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String association;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final String residenceType;
  final String? moveInDate;
  final List<String> users;

  ResidencesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.association,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    required this.residenceType,
    this.moveInDate,
    this.users = const [],
  });

  factory ResidencesRecord.fromJson(Map<String, dynamic> json) {
    return ResidencesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      association: json['association'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      residenceType: json['residence_type'] as String? ?? '',
      moveInDate: json['move_in_date'] as String?,
      users:
          (json['users'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }
}

// --- Parking ---

class ParkingLotsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String? description;
  final String association;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final List<String> images;
  final String parkingType;
  final int? capacity;
  final String? bookingPeriodType;
  final double? pricePerBookingPeriod;
  final String user;

  ParkingLotsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    this.description,
    required this.association,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    this.images = const [],
    required this.parkingType,
    this.capacity,
    this.bookingPeriodType,
    this.pricePerBookingPeriod,
    required this.user,
  });

  factory ParkingLotsRecord.fromJson(Map<String, dynamic> json) {
    return ParkingLotsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      association: json['association'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parkingType: json['parking_type'] as String? ?? '',
      capacity: json['capacity'] as int?,
      bookingPeriodType: json['booking_period_type'] as String?,
      pricePerBookingPeriod: (json['price_per_booking_period'] as num?)
          ?.toDouble(),
      user: json['user'] as String? ?? '',
    );
  }
}

class ParkingSpacesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String parkingLot;
  final String? residence;
  final bool hasChargingStation;
  final String? parkingStartDate;

  ParkingSpacesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.parkingLot,
    this.residence,
    this.hasChargingStation = false,
    this.parkingStartDate,
  });

  factory ParkingSpacesRecord.fromJson(Map<String, dynamic> json) {
    return ParkingSpacesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      parkingLot: json['parking_lot'] as String? ?? '',
      residence: json['residence'] as String?,
      hasChargingStation: json['has_charging_station'] as bool? ?? false,
      parkingStartDate: json['parking_start_date'] as String?,
    );
  }
}

// --- Folders & Files ---

class FoldersAndFilesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String association;
  final String? parentFolder;
  final String path;
  final List<String> files;

  FoldersAndFilesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.association,
    this.parentFolder,
    required this.path,
    this.files = const [],
  });

  factory FoldersAndFilesRecord.fromJson(Map<String, dynamic> json) {
    return FoldersAndFilesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      association: json['association'] as String? ?? '',
      parentFolder: json['parent_folder'] as String?,
      path: json['path'] as String? ?? '',
      files:
          (json['files'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }
}

// --- Board ---

class BoardMeetingsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String association;
  final String startAt;
  final String endAt;
  final String streetAddress;
  final String zipCode;
  final String locality;
  final String meetingProtocolId;
  final List<dynamic>? meetingAgenda;
  final List<dynamic>? meetingProtocol;
  final bool addToCalendar;

  BoardMeetingsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.association,
    required this.startAt,
    required this.endAt,
    required this.streetAddress,
    required this.zipCode,
    required this.locality,
    required this.meetingProtocolId,
    this.meetingAgenda,
    this.meetingProtocol,
    this.addToCalendar = false,
  });

  factory BoardMeetingsRecord.fromJson(Map<String, dynamic> json) {
    return BoardMeetingsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      association: json['association'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      streetAddress: json['street_address'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      meetingProtocolId: json['meeting_protocol_id'] as String? ?? '',
      meetingAgenda: json['meeting_agenda'] as List<dynamic>?,
      meetingProtocol: json['meeting_protocol'] as List<dynamic>?,
      addToCalendar: json['add_to_calendar'] as bool? ?? false,
    );
  }
}

class BoardMeetingTemplatesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String association;
  final List<dynamic>? meetingProtocol;

  BoardMeetingTemplatesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.association,
    this.meetingProtocol,
  });

  factory BoardMeetingTemplatesRecord.fromJson(Map<String, dynamic> json) {
    return BoardMeetingTemplatesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      association: json['association'] as String? ?? '',
      meetingProtocol: json['meeting_protocol'] as List<dynamic>?,
    );
  }
}

// --- Invoices ---

class InvoicesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String invoiceTemplate;
  final String residence;
  final String invoiceDate;
  final String invoiceDispatchDate;
  final String invoiceDueDate;

  InvoicesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.invoiceTemplate,
    required this.residence,
    required this.invoiceDate,
    required this.invoiceDispatchDate,
    required this.invoiceDueDate,
  });

  factory InvoicesRecord.fromJson(Map<String, dynamic> json) {
    return InvoicesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      invoiceTemplate: json['invoice_template'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      invoiceDate: json['invoice_date'] as String? ?? '',
      invoiceDispatchDate: json['invoice_dispatch_date'] as String? ?? '',
      invoiceDueDate: json['invoice_due_date'] as String? ?? '',
    );
  }
}

class InvoiceTemplatesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String association;
  final List<dynamic>? invoiceItems;
  final String? message;
  final String? bankAccountNumber;
  final String? bankAccountType;
  final bool createInvoicesAutomatically;
  final bool sendInvoicesByEmail;

  InvoiceTemplatesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.association,
    this.invoiceItems,
    this.message,
    this.bankAccountNumber,
    this.bankAccountType,
    this.createInvoicesAutomatically = false,
    this.sendInvoicesByEmail = false,
  });

  factory InvoiceTemplatesRecord.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplatesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      association: json['association'] as String? ?? '',
      invoiceItems: json['invoice_items'] as List<dynamic>?,
      message: json['message'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankAccountType: json['bank_account_type'] as String?,
      createInvoicesAutomatically:
          json['create_invoices_automatically'] as bool? ?? false,
      sendInvoicesByEmail: json['send_invoices_by_email'] as bool? ?? false,
    );
  }
}

// --- Forms ---

class FormsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String association;
  final List<dynamic>? formQuestions;

  FormsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.association,
    this.formQuestions,
  });

  factory FormsRecord.fromJson(Map<String, dynamic> json) {
    return FormsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      association: json['association'] as String? ?? '',
      formQuestions: json['form_questions'] as List<dynamic>?,
    );
  }
}

class FormResponsesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String form;
  final String user;
  final Map<String, dynamic>? answers;
  final Map<String, dynamic>? expand;

  FormResponsesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.form,
    required this.user,
    this.answers,
    this.expand,
  });

  factory FormResponsesRecord.fromJson(Map<String, dynamic> json) {
    return FormResponsesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      form: json['form'] as String? ?? '',
      user: json['user'] as String? ?? '',
      answers: json['answers'] as Map<String, dynamic>?,
      expand: json['expand'] as Map<String, dynamic>?,
    );
  }
}

// --- FAQ ---

class FaqRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String description;
  final String? tags;

  FaqRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    required this.description,
    this.tags,
  });

  factory FaqRecord.fromJson(Map<String, dynamic> json) {
    return FaqRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: json['tags'] as String?,
    );
  }
}

// --- Notifications ---

class UserNotificationsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String title;
  final String? subTitle;
  final String? icon;
  final String? actionUrl;
  final bool seen;
  final String user;
  final Map<String, dynamic>? metadata;

  UserNotificationsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.title,
    this.subTitle,
    this.icon,
    this.actionUrl,
    this.seen = false,
    required this.user,
    this.metadata,
  });

  factory UserNotificationsRecord.fromJson(Map<String, dynamic> json) {
    return UserNotificationsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      title: json['title'] as String? ?? '',
      subTitle: json['sub_title'] as String?,
      icon: json['icon'] as String?,
      actionUrl: json['action_url'] as String?,
      seen: json['seen'] as bool? ?? false,
      user: json['user'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class UserNotificationsNotSeenCountViewRecord {
  final String id;
  final String user;
  final int notSeenCount;

  UserNotificationsNotSeenCountViewRecord({
    required this.id,
    required this.user,
    this.notSeenCount = 0,
  });

  factory UserNotificationsNotSeenCountViewRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserNotificationsNotSeenCountViewRecord(
      id: json['id'] as String? ?? '',
      user: json['user'] as String? ?? '',
      notSeenCount: json['not_seen_count'] as int? ?? 0,
    );
  }
}

// --- User Invitations ---

class UserInvitationsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String name;
  final String email;
  final String? phone;
  final String association;
  final String associationType;
  final String userRoleType;
  final List<String> associationRoleTypes;
  final String invitationStatus;
  final String? invitationToken;

  UserInvitationsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.name,
    required this.email,
    this.phone,
    required this.association,
    required this.associationType,
    required this.userRoleType,
    this.associationRoleTypes = const [],
    required this.invitationStatus,
    this.invitationToken,
  });

  factory UserInvitationsRecord.fromJson(Map<String, dynamic> json) {
    return UserInvitationsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      association: json['association'] as String? ?? '',
      associationType: json['association_type'] as String? ?? '',
      userRoleType: json['user_role_type'] as String? ?? '',
      associationRoleTypes:
          (json['association_role_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      invitationStatus: json['invitation_status'] as String? ?? '',
      invitationToken: json['invitation_token'] as String?,
    );
  }
}

// --- Chat ---
//
// Library-agnostic raw chat records shared with the Nuxt (vue-advanced-chat)
// client. A room is a 1:1 DM (isGroup=false, two members) or a named group
// (isGroup=true). `members` are user ids; `expand['members']` carries the full
// user records when fetched with expand.

class ChatRoomsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String association;
  final String? name;
  final bool isGroup;
  final String? createdBy;
  final List<String> members;
  final String? avatar;
  // Expanded member user records (when fetched with expand=members).
  final List<UsersRecord> memberUsers;

  ChatRoomsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.association,
    this.name,
    this.isGroup = false,
    this.createdBy,
    this.members = const [],
    this.avatar,
    this.memberUsers = const [],
  });

  factory ChatRoomsRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final expandedMembers = expand?['members'] as List<dynamic>?;
    return ChatRoomsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      association: json['association'] as String? ?? '',
      name: json['name'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      avatar: json['avatar'] as String?,
      memberUsers:
          expandedMembers
              ?.map((e) => UsersRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ChatMessagesRecord {
  final String id;
  final String? created;
  final String? updated;
  final String room;
  final String sender;
  final String? content;
  final List<String> files;
  final bool deleted;
  final bool edited;
  final String? replyTo;
  // Expanded sender user record (when fetched with expand=sender).
  final UsersRecord? senderUser;

  ChatMessagesRecord({
    required this.id,
    this.created,
    this.updated,
    required this.room,
    required this.sender,
    this.content,
    this.files = const [],
    this.deleted = false,
    this.edited = false,
    this.replyTo,
    this.senderUser,
  });

  factory ChatMessagesRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>?;
    final expandedSender = expand?['sender'] as Map<String, dynamic>?;
    return ChatMessagesRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      room: json['room'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      content: json['content'] as String?,
      files:
          (json['files'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      deleted: json['deleted'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      replyTo: json['reply_to'] as String?,
      senderUser: expandedSender != null
          ? UsersRecord.fromJson(expandedSender)
          : null,
    );
  }
}

class ChatReadReceiptsRecord {
  final String id;
  final String? created;
  final String? updated;
  final String room;
  final String user;
  final String? lastReadMessage;

  ChatReadReceiptsRecord({
    required this.id,
    this.created,
    this.updated,
    required this.room,
    required this.user,
    this.lastReadMessage,
  });

  factory ChatReadReceiptsRecord.fromJson(Map<String, dynamic> json) {
    return ChatReadReceiptsRecord(
      id: json['id'] as String? ?? '',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
      room: json['room'] as String? ?? '',
      user: json['user'] as String? ?? '',
      lastReadMessage: json['last_read_message'] as String?,
    );
  }
}
