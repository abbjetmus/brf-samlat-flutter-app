import 'package:flutter/material.dart';

/// A scrollable list that loads more items as the user nears the bottom
/// (infinite scroll), with an optional pull-to-refresh.
///
/// Pass the already-built (and, if applicable, client-side filtered) item list
/// via [itemCount] + [itemBuilder]. Wire [hasMore]/[loadingMore]/[onLoadMore] to
/// a `Paginated` cursor in the store; a trailing spinner is shown automatically
/// while more pages exist or are loading.
class PaginatedListView extends StatefulWidget {
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
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - widget.scrollThreshold &&
        widget.hasMore &&
        !widget.loadingMore) {
      widget.onLoadMore();
    }
  }

  Widget _trailing() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context) {
    final showTrailing = widget.hasMore || widget.loadingMore;
    final count = widget.itemCount + (showTrailing ? 1 : 0);
    final physics = const AlwaysScrollableScrollPhysics();

    final sep = widget.separatorBuilder;
    final Widget list = sep == null
        ? ListView.builder(
            controller: _controller,
            physics: physics,
            padding: widget.padding,
            itemCount: count,
            itemBuilder: (ctx, i) => i >= widget.itemCount
                ? _trailing()
                : widget.itemBuilder(ctx, i),
          )
        : ListView.separated(
            controller: _controller,
            physics: physics,
            padding: widget.padding,
            itemCount: count,
            // No separator between the last real item and the trailing spinner.
            separatorBuilder: (ctx, i) => i >= widget.itemCount - 1
                ? const SizedBox.shrink()
                : sep(ctx, i),
            itemBuilder: (ctx, i) => i >= widget.itemCount
                ? _trailing()
                : widget.itemBuilder(ctx, i),
          );

    if (widget.onRefresh == null) return list;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }
}
