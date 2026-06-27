/// Helpers for turning a notification `action_url` into a go_router path.
class NotificationLinkUtils {
  /// Converts a notification `action_url` into a safe, absolute go_router path,
  /// or returns `null` when no usable path can be derived (so callers skip
  /// navigation instead of crashing the router).
  ///
  /// `action_url` may be:
  ///  * a full universal link — `https://brfsamlat.se/app/posts/detail/X`
  ///  * a bare in-app path — `/posts/detail/X`
  ///  * a malformed value — e.g. `undefined/posts/detail/X`, produced when the
  ///    backend's `deep_link_base` config was missing. go_router only accepts
  ///    absolute paths; a scheme-less relative string crashes the matcher with
  ///    `uriPathToCompare.startsWith(...)`, so it must be repaired or dropped.
  ///
  /// The `/app` prefix on universal links is intentionally kept — the router's
  /// authGuard strips it during redirect.
  static String? resolvePath(String? actionUrl) {
    if (actionUrl == null || actionUrl.isEmpty) return null;

    final uri = Uri.tryParse(actionUrl);
    String path;
    if (uri != null && uri.hasScheme) {
      path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    } else {
      path = actionUrl;
    }

    // Repair relative strings (e.g. "undefined/posts/detail/X") by keeping the
    // path from the first slash onward.
    if (!path.startsWith('/')) {
      final slash = path.indexOf('/');
      if (slash <= 0) return null;
      path = path.substring(slash);
    }

    // Collapse accidental empty segments ("/app//posts" -> "/app/posts"), which
    // also crash the matcher.
    path = path.replaceAll(RegExp(r'/{2,}'), '/');

    return path.isEmpty || path == '/' ? null : path;
  }
}
