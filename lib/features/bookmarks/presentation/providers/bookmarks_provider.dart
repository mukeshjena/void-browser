import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/bookmark_entity.dart';
import '../../data/models/bookmark_model.dart';
import '../../../../core/constants/storage_constants.dart';

class BookmarksNotifier extends StateNotifier<List<BookmarkEntity>> {
  final Box _bookmarksBox;
  final Uuid _uuid = const Uuid();

  BookmarksNotifier(this._bookmarksBox) : super([]) {
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final bookmarks = _bookmarksBox.values
        .cast<BookmarkModel>()
        .map((model) => model.toEntity())
        .toList();
    bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = bookmarks;
  }

  Future<void> addBookmark({
    required String title,
    required String url,
    String? faviconUrl,
    String? folderName,
  }) async {
    final bookmark = BookmarkModel(
      id: _uuid.v4(),
      title: title,
      url: url,
      faviconUrl: faviconUrl,
      folderName: folderName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _bookmarksBox.put(bookmark.id, bookmark);
    _loadBookmarks();
  }

  Future<void> updateBookmark(BookmarkEntity bookmark) async {
    final model = BookmarkModel.fromEntity(bookmark.copyWith(
      updatedAt: DateTime.now(),
    ));
    await _bookmarksBox.put(model.id, model);
    _loadBookmarks();
  }

  Future<void> deleteBookmark(String id) async {
    await _bookmarksBox.delete(id);
    _loadBookmarks();
  }

  List<BookmarkEntity> searchBookmarks(String query) {
    if (query.isEmpty) return state;

    final lowerQuery = query.toLowerCase();
    return state.where((bookmark) {
      return bookmark.title.toLowerCase().contains(lowerQuery) ||
          bookmark.url.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<BookmarkEntity> getBookmarksByFolder(String? folderName) {
    return state.where((bookmark) => bookmark.folderName == folderName).toList();
  }

  bool isBookmarked(String url) {
    return state.any((bookmark) => bookmark.url == url);
  }

  Future<void> exportBookmarks() async {
    // Implementation for exporting to JSON
  }

  Future<void> importBookmarks(String json) async {
    // Implementation for importing from JSON
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<BookmarkEntity>>((ref) {
  final box = Hive.box(StorageConstants.bookmarksBox);
  return BookmarksNotifier(box);
});

