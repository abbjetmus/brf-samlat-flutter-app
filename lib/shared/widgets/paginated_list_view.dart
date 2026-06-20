import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// A scrollable list that loads more items as the user nears the bottom
/// (infinite scroll), with an optional pull-to-refresh.
///
/// Pass the already-built (and, if applicable, client-side filtered) item list
/// via [itemCount] + [itemBuilder]. Wire [hasMore]/[loadingMore]/[onLoadMore] to
/// a `Paginated` cursor in the store; a trailing spinner is shown automatically
/// while more pages exist or are loading.
class PaginatedListView extends CompositionWidget {
  const PaginatedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    this.separatorBuilder,
    this.onRefresh,
    this.padding,
    this.scrollThreshold = 200,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// When provided, renders as a [ListView.separated].
  final IndexedWidgetBuilder? separatorBuilder;

  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;

  /// When provided, wraps the list in a [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  final EdgeInsetsGeometry? padding;

  /// Distance (px) from the bottom at which to trigger [onLoadMore].
  final double scrollThreshold;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final scrollRef = useScrollController();

    void onScroll() {
      final controller = scrollRef.value;
      if (!controller.hasClients) return;
      final pos = controller.position;
      final p = props.value;
      if (pos.pixels >= pos.maxScrollExtent - p.scrollThreshold &&
          p.hasMore &&
          !p.loadingMore) {
        p.onLoadMore();
      }
    }

    // The controller is created synchronously by useScrollController and
    // auto-disposed on unmount (which also drops this listener).
    scrollRef.value.addListener(onScroll);

    Widget trailing() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );

    return (context) {
      final p = props.value;
      final showTrailing = p.hasMore || p.loadingMore;
      final count = p.itemCount + (showTrailing ? 1 : 0);
      const physics = AlwaysScrollableScrollPhysics();

      final sep = p.separatorBuilder;
      final Widget list = sep == null
          ? ListView.builder(
              controller: scrollRef.value,
              physics: physics,
              padding: p.padding,
              itemCount: count,
              itemBuilder: (ctx, i) =>
                  i >= p.itemCount ? trailing() : p.itemBuilder(ctx, i),
            )
          : ListView.separated(
              controller: scrollRef.value,
              physics: physics,
              padding: p.padding,
              itemCount: count,
              // No separator between the last real item and the trailing spinner.
              separatorBuilder: (ctx, i) =>
                  i >= p.itemCount - 1 ? const SizedBox.shrink() : sep(ctx, i),
              itemBuilder: (ctx, i) =>
                  i >= p.itemCount ? trailing() : p.itemBuilder(ctx, i),
            );

      if (p.onRefresh == null) return list;
      return RefreshIndicator(onRefresh: p.onRefresh!, child: list);
    };
  }
}
