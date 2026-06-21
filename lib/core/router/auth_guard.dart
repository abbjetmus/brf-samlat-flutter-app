import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../di/injection_keys.dart';
import '../../features/auth/pages/login_page.dart';

Future<String?> authGuard(BuildContext context, GoRouterState state) async {
  // Universal / App Links arrive as https://brfsamlat.se/app/... and the native
  // layer hands go_router the path "/app/...". Strip the web prefix so it maps
  // onto the in-app route, e.g. /app/posts/detail/X -> /posts/detail/X.
  final path = state.uri.path;
  if (path == '/app' || path.startsWith('/app/')) {
    final stripped = path == '/app' ? '/' : path.substring(4);
    final query = state.uri.query;
    return query.isEmpty ? stripped : '$stripped?$query';
  }

  try {
    final authStore = getGlobalAuthStore();
    if (authStore == null) return LoginPage.path;

    final isAuthenticated = authStore.isAuthenticated.value;
    final isAuthRoute = state.uri.path == LoginPage.path ||
        state.uri.path == '/register' ||
        state.uri.path == '/forgot-password';

    if (!isAuthenticated && !isAuthRoute) {
      return LoginPage.path;
    }

    if (isAuthenticated && isAuthRoute) {
      return '/';
    }
  } catch (e) {
    return LoginPage.path;
  }

  return null;
}
