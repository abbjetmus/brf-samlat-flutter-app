import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// Result of fetching one page: the typed items plus the total page count
/// (from PocketBase's ResultList.totalPages).
class PageResult<T> {
  const PageResult(this.items, this.totalPages);
  final List<T> items;
  final int totalPages;
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(int page, int perPage);

/// Reusable cursor for offset-paginated PocketBase lists.
///
/// Holds the reactive item list + loading flags and exposes [refresh] (load /
/// reload the first page) and [loadMore] (append the next page). Create one per
/// list in a store and pass it a fetcher that builds the query:
///
/// ```dart
/// final _posts = Paginated<PostsViewRecord>((page, perPage) async {
///   final res = await _pb.collection(Collections.postsView).getList(
///     page: page, perPage: perPage, filter: '...', sort: '-created');
///   return PageResult(
///     res.items.map((r) => PostsViewRecord.fromJson(r.toJson())).toList(),
///     res.totalPages,
///   );
/// });
/// ```
///
/// Pair with `PaginatedListView` on the UI side.
class Paginated<T> {
  Paginated(this._fetch, {this.pageSize = 20});

  final PageFetcher<T> _fetch;
  final int pageSize;

  final _items = ref<List<T>>([]);
  final _loading = ref<bool>(false);
  final _loadingMore = ref<bool>(false);
  final _hasMore = ref<bool>(false);
  int _page = 1;

  Ref<List<T>> get items => _items;

  /// True while the first page is (re)loading.
  Ref<bool> get loading => _loading;

  /// True while a subsequent page is appending.
  Ref<bool> get loadingMore => _loadingMore;

  /// True when there are more pages to load.
  Ref<bool> get hasMore => _hasMore;

  /// Load (or reload) the first page, replacing the current items.
  Future<void> refresh() async {
    _loading.value = true;
    _page = 1;
    try {
      final result = await _fetch(_page, pageSize);
      _items.value = result.items;
      _hasMore.value = _page < result.totalPages;
    } catch (e) {
      debugPrint('Paginated<$T>: refresh error: $e');
      _items.value = [];
      _hasMore.value = false;
    } finally {
      _loading.value = false;
    }
  }

  /// Append the next page. No-op while already (re)loading or when there is
  /// nothing more to load.
  Future<void> loadMore() async {
    if (!_hasMore.value || _loadingMore.value || _loading.value) return;
    _loadingMore.value = true;
    _page++;
    try {
      final result = await _fetch(_page, pageSize);
      _items.value = [..._items.value, ...result.items];
      _hasMore.value = _page < result.totalPages;
    } catch (e) {
      debugPrint('Paginated<$T>: loadMore error: $e');
      _page--; // roll back so the next attempt retries this page
    } finally {
      _loadingMore.value = false;
    }
  }
}
