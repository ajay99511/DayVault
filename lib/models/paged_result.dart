class PaginationCursor {
  final int _lastId;

  /// Only meant to be called by [StorageService].
  const PaginationCursor.fromLastId(int id) : _lastId = id;

  int get lastId => _lastId;
}

class PagedResult<T> {
  final List<T> items;
  final PaginationCursor? nextCursor;

  const PagedResult({required this.items, this.nextCursor});
}
