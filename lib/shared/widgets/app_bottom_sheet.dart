import 'package:flutter/material.dart';

/// Shows a modal bottom sheet whose content never slides under the Android
/// system navigation bar (gesture pill / 3-button bar) or the status bar.
///
/// On edge-to-edge Android a plain [showModalBottomSheet] lets tall content
/// render full-screen — the drag handle ends up under the status bar and there's
/// no scrim left to tap to dismiss. We always pass `useSafeArea: true`, cap the
/// height so a dismissable scrim stays visible at the top, keep the drag handle
/// pinned while only the body scrolls, and the wrapping container adds the
/// keyboard/nav-bar inset so the content stays clear of both. Use this
/// everywhere instead of calling [showModalBottomSheet] directly.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  // Leave a visible scrim at the top so a long sheet never reaches the app bar
  // and can always be dismissed by tapping outside it.
  final maxHeight = MediaQuery.of(context).size.height * 0.9;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AppBottomSheetContainer(
      showDragHandle: showDragHandle,
      child: builder(context),
    ),
  );
}

class _AppBottomSheetContainer extends StatelessWidget {
  const _AppBottomSheetContainer({
    required this.child,
    required this.showDragHandle,
  });

  final Widget child;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // `useSafeArea: true` only pads top/left/right — bottom sheets are meant to
    // reach the screen edge, so the framework leaves the bottom alone and our
    // content would slide under the Android nav bar. Pad it ourselves: the nav
    // bar (viewPadding.bottom) when the keyboard is closed, the keyboard
    // (viewInsets.bottom) when it's open (the keyboard already covers the bar).
    final bottomInset = mq.viewInsets.bottom > mq.viewPadding.bottom
        ? mq.viewInsets.bottom
        : mq.viewPadding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Only the body scrolls; the drag handle above stays pinned so the sheet
        // can always be dragged down / dismissed even when content is long.
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
