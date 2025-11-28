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

  /// Normalize URL for comparison (remove trailing slash, convert to lowercase)
  String _normalizeUrl(String url) {
    String normalized = url.trim().toLowerCase();
    // Remove trailing slash except for root URLs
    if (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    // Remove www. prefix for comparison
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    }
    return normalized;
  }

  /// Add a bookmark. Returns true if added, false if already exists.
  /// If bookmark already exists, it will be updated with new title/favicon if provided.
  Future<bool> addBookmark({
    required String title,
    required String url,
    String? faviconUrl,
    String? folderName,
  }) async {
    // Normalize URL for comparison
    final normalizedUrl = _normalizeUrl(url);
    
    // Check if bookmark with same URL already exists
    final existingBookmark = state.firstWhere(
      (bookmark) => _normalizeUrl(bookmark.url) == normalizedUrl,
      orElse: () => BookmarkEntity(
        id: '',
        title: '',
        url: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (existingBookmark.id.isNotEmpty) {
      // Bookmark already exists - update it with new information
      final updatedBookmark = existingBookmark.copyWith(
        title: title,
        faviconUrl: faviconUrl ?? existingBookmark.faviconUrl,
        folderName: folderName ?? existingBookmark.folderName,
        updatedAt: DateTime.now(),
      );
      await updateBookmark(updatedBookmark);
      return false; // Already existed
    }

    // Create new bookmark
    final bookmark = BookmarkModel(
      id: _uuid.v4(),
      title: title,
      url: url, // Keep original URL format
      faviconUrl: faviconUrl,
      folderName: folderName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _bookmarksBox.put(bookmark.id, bookmark);
    _loadBookmarks();
    return true; // Successfully added
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
    final normalizedUrl = _normalizeUrl(url);
    return state.any((bookmark) => _normalizeUrl(bookmark.url) == normalizedUrl);
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

