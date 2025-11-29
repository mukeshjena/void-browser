import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/quick_link_model.dart';
import '../../domain/entities/quick_link_entity.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../main.dart';

// State for quick links
class QuickLinksState {
  final List<QuickLinkEntity> links;
  final bool isLoading;

  QuickLinksState({
    this.links = const [],
    this.isLoading = false,
  });

  QuickLinksState copyWith({
    List<QuickLinkEntity>? links,
    bool? isLoading,
  }) {
    return QuickLinksState(
      links: links ?? this.links,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Quick links notifier
class QuickLinksNotifier extends StateNotifier<QuickLinksState> {
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  QuickLinksNotifier(this._prefs) : super(QuickLinksState()) {
    _loadQuickLinks();
  }

  void _loadQuickLinks() {
    try {
      final linksJson = _prefs.getString(StorageConstants.keyQuickLinks);
      if (linksJson != null) {
        final List<dynamic> linksList = jsonDecode(linksJson);
        final links = linksList
            .map((json) => QuickLinkModel.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(links: links);
      } else {
        // Initialize with default links
        _initializeDefaultLinks();
      }
    } catch (e) {
      // If loading fails, initialize with defaults
      _initializeDefaultLinks();
    }
  }

  void _initializeDefaultLinks() {
    final defaultLinks = [
      QuickLinkModel(
        id: _uuid.v4(),
        name: 'YouTube',
        url: 'https://www.youtube.com',
        iconUrl: QuickLinkModel.getFaviconUrl('https://www.youtube.com'),
        createdAt: DateTime.now(),
      ),
      QuickLinkModel(
        id: _uuid.v4(),
        name: 'YouTube Music',
        url: 'https://music.youtube.com',
        iconUrl: QuickLinkModel.getFaviconUrl('https://music.youtube.com'),
        createdAt: DateTime.now(),
      ),
      QuickLinkModel(
        id: _uuid.v4(),
        name: 'Facebook',
        url: 'https://www.facebook.com',
        iconUrl: QuickLinkModel.getFaviconUrl('https://www.facebook.com'),
        createdAt: DateTime.now(),
      ),
      QuickLinkModel(
        id: _uuid.v4(),
        name: 'Instagram',
        url: 'https://www.instagram.com',
        iconUrl: QuickLinkModel.getFaviconUrl('https://www.instagram.com'),
        createdAt: DateTime.now(),
      ),
    ];
    state = state.copyWith(links: defaultLinks);
    _saveQuickLinks();
  }

  Future<void> _saveQuickLinks() async {
    try {
      final linksJson = jsonEncode(
        state.links.map((link) => QuickLinkModel.fromEntity(link).toJson()).toList(),
      );
      await _prefs.setString(StorageConstants.keyQuickLinks, linksJson);
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> addQuickLink(String name, String url) async {
    try {
      // Normalize URL
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      final newLink = QuickLinkModel(
        id: _uuid.v4(),
        name: name.trim(),
        url: normalizedUrl,
        iconUrl: QuickLinkModel.getFaviconUrl(normalizedUrl),
        createdAt: DateTime.now(),
      );

      final updatedLinks = [...state.links, newLink];
      state = state.copyWith(links: updatedLinks);
      await _saveQuickLinks();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeQuickLink(String id) async {
    final updatedLinks = state.links.where((link) => link.id != id).toList();
    state = state.copyWith(links: updatedLinks);
    await _saveQuickLinks();
  }

  Future<void> updateQuickLink(String id, String name, String url) async {
    try {
      // Normalize URL
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      final updatedLinks = state.links.map((link) {
        if (link.id == id) {
          return QuickLinkModel(
            id: link.id,
            name: name.trim(),
            url: normalizedUrl,
            iconUrl: QuickLinkModel.getFaviconUrl(normalizedUrl),
            createdAt: link.createdAt,
          );
        }
        return link;
      }).toList();

      state = state.copyWith(links: updatedLinks);
      await _saveQuickLinks();
    } catch (e) {
      rethrow;
    }
  }
}

// Quick links provider
final quickLinksProvider = StateNotifierProvider<QuickLinksNotifier, QuickLinksState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QuickLinksNotifier(prefs);
});

