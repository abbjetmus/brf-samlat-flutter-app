import 'package:flutter_test/flutter_test.dart';
import 'package:brf_samlat_flutter_app/features/dashboard/widgets/subscription_banner.dart';

SubscriptionStatus status({
  String state = 'active',
  bool cancelled = false,
  String accessUntil = '',
  int days = 0,
  int quota = 5 * 1024 * 1024 * 1024,
  int used = 0,
  bool admin = true,
}) =>
    SubscriptionStatus.fromJson({
      'state': state,
      'cancelled': cancelled,
      'access_until': accessUntil,
      'trial_days_left': days,
      'quota_bytes': quota,
      'used_bytes': used,
      'can_manage': admin,
    });

void main() {
  test('read-only is shown to everyone', () {
    final admin = subscriptionBannerText(status(state: 'expired'));
    final member = subscriptionBannerText(status(state: 'expired', admin: false));
    expect(admin?.title, 'Gratismånaden är slut');
    expect(admin?.body, contains('Administration → Abonnemang'));
    expect(member?.body, contains('föreningens administratör'));
    expect(subscriptionBannerText(status(state: 'cancelled', admin: false))?.title,
        contains('abonnemanget är avslutat'));
  });

  test('trial and cancellation are only shown to admins', () {
    expect(subscriptionBannerText(status(state: 'trial', days: 20, admin: false)), isNull);
    final trial = subscriptionBannerText(status(state: 'trial', days: 20));
    expect(trial?.title, 'Gratismånad – 20 dagar kvar');
    expect(trial?.attention, isFalse);
    expect(subscriptionBannerText(status(state: 'trial', days: 1))?.title, 'Gratismånad – 1 dag kvar');
    expect(subscriptionBannerText(status(state: 'trial', days: 5))?.attention, isTrue);
    final cancelling = subscriptionBannerText(
      status(cancelled: true, accessUntil: '2026-12-13T00:00:00.000Z'),
    );
    expect(cancelling?.title, 'Abonnemanget är uppsagt');
    expect(cancelling?.body, contains('december 2026'));
  });

  test('storage warning at 90 %, nothing when active and fine', () {
    final gb = 1024 * 1024 * 1024;
    expect(subscriptionBannerText(status(used: (4.6 * gb).round()))?.body, startsWith('4,6 GB av 5 GB'));
    expect(subscriptionBannerText(status(used: gb)), isNull);
    expect(formatStorage(10 * gb), '10 GB');
    expect(formatStorage((0.8 * gb).round()), '0,8 GB');
  });
}
