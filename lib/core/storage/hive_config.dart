import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_constants.dart';
import '../../features/bookmarks/data/models/bookmark_model.dart';
import '../../features/downloads/data/models/download_model.dart';
import '../../features/search/data/models/search_history_model.dart';
import 'cache_service.dart';

class HiveConfig {
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookmarkModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DownloadModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SearchHistoryModelAdapter());
    }
    
    // Initialize cache service
    await CacheService.init();
  }

  static Future<Box> openBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  static Future<void> openAllBoxes() async {
    await Future.wait([
      openBox(StorageConstants.bookmarksBox),
      openBox(StorageConstants.tabsBox),
      openBox(StorageConstants.downloadsBox),
      openBox(StorageConstants.settingsBox),
      openBox(StorageConstants.cacheBox),
      openBox(StorageConstants.historyBox),
      openBox(StorageConstants.filtersBox),
    ]);
  }

  static Future<void> clearCache() async {
    final cacheBox = await openBox(StorageConstants.cacheBox);
    await cacheBox.clear();
  }

  static Future<void> clearAll() async {
    await Hive.deleteFromDisk();
  }
}

