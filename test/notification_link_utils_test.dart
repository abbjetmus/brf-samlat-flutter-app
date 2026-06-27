import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brf_samlat_flutter_app/core/utils/notification_link_utils.dart';

void main() {
  group('NotificationLinkUtils.resolvePath', () {
    test('full universal link keeps /app prefix', () {
      expect(
        NotificationLinkUtils.resolvePath(
            'https://brfsamlat.se/app/posts/detail/X'),
        '/app/posts/detail/X',
      );
    });

    test('bare in-app path passes through', () {
      expect(
        NotificationLinkUtils.resolvePath('/posts/detail/X'),
        '/posts/detail/X',
      );
    });

    test('preserves query string', () {
      expect(
        NotificationLinkUtils.resolvePath(
            'https://brfsamlat.se/app/issues/create?residenceId=1'),
        '/app/issues/create?residenceId=1',
      );
    });

    test('repairs malformed "undefined/..." (missing deep_link_base)', () {
      expect(
        NotificationLinkUtils.resolvePath('undefined/posts/detail/X'),
        '/posts/detail/X',
      );
    });

    test('collapses accidental double slashes', () {
      expect(
        NotificationLinkUtils.resolvePath('/app//posts/detail/X'),
        '/app/posts/detail/X',
      );
    });

    test('returns null for null/empty/unusable values', () {
      expect(NotificationLinkUtils.resolvePath(null), isNull);
      expect(NotificationLinkUtils.resolvePath(''), isNull);
      expect(NotificationLinkUtils.resolvePath('undefined'), isNull);
      expect(NotificationLinkUtils.resolvePath('/'), isNull);
    });
  });

  testWidgets('router.go on resolved malformed path does not crash',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => const Text('home')),
        GoRoute(
          path: '/posts/detail/:id',
          builder: (c, s) => Text('post:${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final path =
        NotificationLinkUtils.resolvePath('undefined/posts/detail/abc123');
    router.go(path!);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/posts/detail/abc123');
    expect(tester.takeException(), isNull);
  });
}
