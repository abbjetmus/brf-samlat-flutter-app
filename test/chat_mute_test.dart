import 'package:brf_samlat_flutter_app/core/models/pocketbase_models.dart';
import 'package:brf_samlat_flutter_app/features/chat/widgets/chat_mute_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMutesRecord', () {
    test('empty until = muted until further notice', () {
      final mute = ChatMutesRecord.fromJson({
        'id': 'm1',
        'user': 'u1',
        'room': 'r1',
        'until': '',
      });
      expect(mute.until, isNull);
      expect(mute.isActive, isTrue);
      expect(chatMuteHint(mute), 'Avstängt tills vidare');
    });

    test('parses PocketBase dates to local time', () {
      final mute = ChatMutesRecord.fromJson({
        'id': 'm1',
        'user': 'u1',
        'room': 'r1',
        'until': '2099-11-18 13:30:00.000Z',
      });
      expect(mute.until, isNotNull);
      expect(mute.until!.isUtc, isFalse);
      expect(mute.until!.toUtc(), DateTime.utc(2099, 11, 18, 13, 30));
      expect(mute.isActive, isTrue);
    });

    test('a past until is not active', () {
      final mute = ChatMutesRecord.fromJson({
        'id': 'm1',
        'user': 'u1',
        'room': 'r1',
        'until': '2000-01-01 00:00:00.000Z',
      });
      expect(mute.isActive, isFalse);
    });
  });

  group('chatMuteHint', () {
    test('formats day, short Swedish month and time', () {
      final mute = ChatMutesRecord(
        id: 'm1',
        user: 'u1',
        room: 'r1',
        until: DateTime(2026, 11, 18, 14, 30),
      );
      expect(
        chatMuteHint(mute, now: DateTime(2026, 11, 17)),
        'Avstängt till 18 nov 14:30',
      );
    });

    test('adds the year when it is not the current one', () {
      final mute = ChatMutesRecord(
        id: 'm1',
        user: 'u1',
        room: 'r1',
        until: DateTime(2027, 1, 2, 8, 5),
      );
      expect(
        chatMuteHint(mute, now: DateTime(2026, 12, 30)),
        'Avstängt till 2 jan 2027 08:05',
      );
    });
  });
}
