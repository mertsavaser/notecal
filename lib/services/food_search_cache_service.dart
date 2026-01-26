import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Cache entry for in-memory LRU cache
class _CacheEntry {
  final List<Map<String, dynamic>> results;
  final DateTime timestamp;

  _CacheEntry(this.results, this.timestamp);

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

/// Service for caching food search results and recently used foods
class FoodSearchCacheService {
  static const String _recentlyUsedKey = 'food_search_recently_used';
  static const int _maxRecentlyUsed = 50;
  static const int _maxMemoryCacheSize = 50;
  static const Duration _memoryCacheTTL = Duration(minutes: 10);

  // In-memory LRU cache for search queries
  final Map<String, _CacheEntry> _memoryCache = {};
  final List<String> _cacheAccessOrder = []; // For LRU eviction

  /// Normalize query string (lowercase, trim)
  static String normalizeQuery(String query) {
    return query.toLowerCase().trim();
  }

  /// Get cached search results if available and not expired
  List<Map<String, dynamic>>? getCachedResults(String query) {
    final normalized = normalizeQuery(query);
    final entry = _memoryCache[normalized];

    if (entry == null) {
      return null;
    }

    if (entry.isExpired(_memoryCacheTTL)) {
      _memoryCache.remove(normalized);
      _cacheAccessOrder.remove(normalized);
      return null;
    }

    // Update access order (move to end)
    _cacheAccessOrder.remove(normalized);
    _cacheAccessOrder.add(normalized);

    AppLogger.d('FoodSearchCache', 'Cache HIT for query: $normalized');
    return entry.results;
  }

  /// Store search results in memory cache
  void cacheResults(String query, List<Map<String, dynamic>> results) {
    final normalized = normalizeQuery(query);

    // Remove if already exists
    if (_memoryCache.containsKey(normalized)) {
      _cacheAccessOrder.remove(normalized);
    }

    // Add new entry
    _memoryCache[normalized] = _CacheEntry(results, DateTime.now());
    _cacheAccessOrder.add(normalized);

    // Evict oldest if cache is full
    if (_memoryCache.length > _maxMemoryCacheSize) {
      final oldest = _cacheAccessOrder.removeAt(0);
      _memoryCache.remove(oldest);
      AppLogger.d('FoodSearchCache', 'Evicted cache entry: $oldest');
    }

    AppLogger.d('FoodSearchCache',
        'Cached results for query: $normalized (${results.length} items)');
  }

  /// Get recently used foods from persistent storage
  Future<List<Map<String, dynamic>>> getRecentlyUsedFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentlyUsedKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      final recentlyUsed =
          decoded.map((item) => item as Map<String, dynamic>).toList();

      AppLogger.d('FoodSearchCache',
          'Loaded ${recentlyUsed.length} recently used foods');
      return recentlyUsed;
    } catch (e) {
      AppLogger.e('FoodSearchCache', 'Error loading recently used foods', e);
      return [];
    }
  }

  /// Add or update a food in recently used list
  Future<void> addToRecentlyUsed(Map<String, dynamic> food) async {
    try {
      final recentlyUsed = await getRecentlyUsedFoods();

      // Extract key fields for storage
      final foodId = food['id'] as String? ?? '';
      final displayName = food['name'] as String? ?? '';

      // Check if already exists (by foodId or name)
      recentlyUsed.removeWhere((item) =>
          (item['id'] as String?) == foodId ||
          (item['displayName'] as String?) == displayName);

      // Add to front
      recentlyUsed.insert(0, {
        'id': foodId,
        'displayName': displayName,
        'caloriesPer100': (food['calories'] as num?)?.toDouble() ?? 0.0,
        'proteinPer100': (food['protein'] as num?)?.toDouble() ?? 0.0,
        'carbsPer100': (food['carbs'] as num?)?.toDouble() ?? 0.0,
        'fatPer100': (food['fat'] as num?)?.toDouble() ?? 0.0,
        'servingSize': (food['serving_size'] as num?)?.toDouble() ?? 100.0,
        'servingUnit': food['serving_unit'] as String? ?? 'g',
        'category': food['category'] as String?,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });

      // Keep only top N
      if (recentlyUsed.length > _maxRecentlyUsed) {
        recentlyUsed.removeRange(_maxRecentlyUsed, recentlyUsed.length);
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentlyUsedKey, jsonEncode(recentlyUsed));

      AppLogger.d('FoodSearchCache', 'Added to recently used: $displayName');
    } catch (e) {
      AppLogger.e('FoodSearchCache', 'Error adding to recently used', e);
    }
  }

  /// Clear all caches (for testing/debugging)
  Future<void> clearAllCaches() async {
    _memoryCache.clear();
    _cacheAccessOrder.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentlyUsedKey);

    AppLogger.d('FoodSearchCache', 'All caches cleared');
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheSize': _maxMemoryCacheSize,
      'memoryCacheTTL': _memoryCacheTTL.inMinutes,
    };
  }
}
