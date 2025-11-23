import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/storage/hive_config.dart';
import '../../domain/entities/tab_entity.dart';
import '../../data/models/tab_model.dart';

// State for tabs
class TabsState {
  final List<TabEntity> tabs;
  final String? activeTabId;
  final bool isLoading;

  TabsState({
    this.tabs = const [],
    this.activeTabId,
    this.isLoading = false,
  });

  TabsState copyWith({
    List<TabEntity>? tabs,
    String? activeTabId,
    bool? isLoading,
  }) {
    return TabsState(
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  TabEntity? get activeTab {
    if (activeTabId == null) return null;
    try {
      return tabs.firstWhere((tab) => tab.id == activeTabId);
    } catch (e) {
      return null;
    }
  }

  int get tabCount => tabs.length;
}

// Tabs notifier
class TabsNotifier extends StateNotifier<TabsState> {
  final Uuid _uuid = const Uuid();
  Box? _tabsBox;

  TabsNotifier() : super(TabsState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      _tabsBox = await HiveConfig.openBox(StorageConstants.tabsBox);
      await _loadTabs();
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadTabs() async {
    try {
      if (_tabsBox == null) {
        _tabsBox = await HiveConfig.openBox(StorageConstants.tabsBox);
      }
      
      final tabsJson = _tabsBox?.get('tabs') as String?;
      if (tabsJson != null && tabsJson.isNotEmpty) {
        final List<dynamic> tabsList = jsonDecode(tabsJson);
        final tabs = tabsList
            .map((json) => TabModel.fromJson(json as Map<String, dynamic>).toEntity())
            .toList();
        
        // Get active tab ID
        final activeTabId = _tabsBox?.get('activeTabId') as String?;
        
        // Validate active tab exists in loaded tabs
        final validActiveTabId = tabs.isNotEmpty && activeTabId != null && tabs.any((tab) => tab.id == activeTabId)
            ? activeTabId
            : (tabs.isNotEmpty ? tabs.first.id : null);
        
        state = state.copyWith(
          tabs: tabs,
          activeTabId: validActiveTabId,
          isLoading: false,
        );
      } else {
        // No saved tabs, create initial tab with discover page
        final newTab = TabEntity(
          id: _uuid.v4(),
          url: 'discover',
          createdAt: DateTime.now(),
          isIncognito: false,
        );
        state = state.copyWith(
          tabs: [newTab],
          activeTabId: newTab.id,
          isLoading: false,
        );
        await _saveTabs();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      // Create initial tab on error
      final newTab = TabEntity(
        id: _uuid.v4(),
        url: 'discover',
        createdAt: DateTime.now(),
        isIncognito: false,
      );
      state = state.copyWith(
        tabs: [newTab],
        activeTabId: newTab.id,
      );
      await _saveTabs();
    }
  }

  Future<void> _saveTabs() async {
    try {
      if (_tabsBox == null) {
        _tabsBox = await HiveConfig.openBox(StorageConstants.tabsBox);
      }
      
      final tabsJson = jsonEncode(
        state.tabs.map((tab) => TabModel.fromEntity(tab).toJson()).toList(),
      );
      await _tabsBox?.put('tabs', tabsJson);
      if (state.activeTabId != null) {
        await _tabsBox?.put('activeTabId', state.activeTabId);
      } else {
        await _tabsBox?.delete('activeTabId');
      }
    } catch (e) {
      // Silently fail - tabs will be recreated on next load
      print('Error saving tabs: $e');
    }
  }

  Future<void> createNewTab({String? url, bool isIncognito = false}) async {
    final newTab = TabEntity(
      id: _uuid.v4(),
      url: url ?? 'discover', // 'discover' means show discover page
      createdAt: DateTime.now(),
      isIncognito: isIncognito,
    );

    final updatedTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: updatedTabs,
      activeTabId: newTab.id,
    );

    await _saveTabs();
  }

  Future<void> closeTab(String tabId) async {
    final updatedTabs = state.tabs.where((tab) => tab.id != tabId).toList();
    String? newActiveTabId = state.activeTabId;

    // If we're closing the active tab, switch to another one
    if (tabId == state.activeTabId) {
      final closedIndex = state.tabs.indexWhere((tab) => tab.id == tabId);
      if (closedIndex > 0) {
        newActiveTabId = state.tabs[closedIndex - 1].id;
      } else if (updatedTabs.isNotEmpty) {
        newActiveTabId = updatedTabs.first.id;
      } else {
        newActiveTabId = null;
      }
    }

    // If no tabs remain, create a new discover tab (replace, don't add)
    if (updatedTabs.isEmpty) {
      final newTab = TabEntity(
        id: _uuid.v4(),
        url: 'discover',
        createdAt: DateTime.now(),
        isIncognito: false,
      );
      state = state.copyWith(
        tabs: [newTab],
        activeTabId: newTab.id,
      );
      await _saveTabs();
      return;
    }

    state = state.copyWith(
      tabs: updatedTabs,
      activeTabId: newActiveTabId,
    );

    await _saveTabs();
  }

  Future<void> switchToTab(String tabId) async {
    if (state.tabs.any((tab) => tab.id == tabId)) {
      state = state.copyWith(activeTabId: tabId);
      await _saveTabs();
    }
  }

  Future<void> updateTab({
    required String tabId,
    String? url,
    String? title,
    String? favicon,
  }) async {
    final updatedTabs = state.tabs.map((tab) {
      if (tab.id == tabId) {
        return tab.copyWith(
          url: url ?? tab.url,
          title: title ?? tab.title,
          favicon: favicon ?? tab.favicon,
        );
      }
      return tab;
    }).toList();

    state = state.copyWith(tabs: updatedTabs);
    await _saveTabs();
  }

  Future<void> closeAllTabs() async {
    // Clear all tabs and create a new one with discover page
    final newTab = TabEntity(
      id: _uuid.v4(),
      url: 'discover',
      createdAt: DateTime.now(),
      isIncognito: false,
    );

    state = state.copyWith(
      tabs: [newTab],
      activeTabId: newTab.id,
    );

    await _saveTabs();
  }

  Future<void> closeOtherTabs(String keepTabId) async {
    final keepTab = state.tabs.firstWhere((tab) => tab.id == keepTabId);
    state = state.copyWith(
      tabs: [keepTab],
      activeTabId: keepTabId,
    );
    await _saveTabs();
  }
}

// Tabs provider
final tabsProvider = StateNotifierProvider<TabsNotifier, TabsState>((ref) {
  return TabsNotifier();
});

