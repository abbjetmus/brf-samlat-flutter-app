import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../di/injection_keys.dart';
import '../../features/auth/pages/login_page.dart';

Future<String?> authGuard(BuildContext context, GoRouterState state) async {
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
