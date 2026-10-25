import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_waste.dart';
import '../models/waste_guide.dart';

/// Manages the user's locally-saved Waste Guide items and AI scan results.
class WasteGuideController extends ChangeNotifier {
  WasteGuideController._();
  static final WasteGuideController instance = WasteGuideController._();

  static const String _prefsKey = 'saved_guide_items_v2';
  static const String _savedResultsKey = 'saved_scan_results_v1';
  static const String _savedAiResultsKey = 'saved_ai_results_v1';

  List<String> _savedIds = [];
  List<String> _savedResultCategories = []; // category names from AI scans (legacy)
  List<SavedAiWaste> _savedAiResults = []; // Full AI results with images
  bool _loaded = false;
  String? _selectedCategory;

  bool get isLoaded => _loaded;
  String? get selectedCategory => _selectedCategory;

  /// Test helper: fully clear in-memory state and release the loaded flag so a
  /// fresh [load] behaves like a new app session.
  @visibleForTesting
  void clearForTest() {
    _savedIds = [];
    _savedResultCategories = [];
    _savedAiResults = [];
    _loaded = false;
    _selectedCategory = null;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// The saved items in the order the user saved them.
  List<WasteGuideItem> get savedItems {
    final byId = {for (final item in WasteGuideData.items) item.id: item};
    return _savedIds.map((id) => byId[id]).whereType<WasteGuideItem>().toList();
  }

  /// Saved AI scan result category names (deduplicated, newest first) - legacy.
  List<String> get savedResultCategories => List.unmodifiable(_savedResultCategories);

  /// Saved AI scan results with full data including images (newest first).
  List<SavedAiWaste> get savedAiResults => List.unmodifiable(_savedAiResults);

  bool isSaved(String id) => _savedIds.contains(id);

  bool isResultSaved(String categoryName) => _savedResultCategories.contains(categoryName);

  /// Check if a specific AI result is saved (by category).
  /// NOTE: Now allows multiple saves of the same category with different images.
  bool isAiResultSaved(String categoryName) {
    return _savedAiResults.any((r) => r.category.toLowerCase() == categoryName.toLowerCase());
  }
  
  /// Get count of saved results for a specific category.
  int getSavedCountForCategory(String categoryName) {
    return _savedAiResults.where((r) => r.category.toLowerCase() == categoryName.toLowerCase()).length;
  }
  
  /// Get all saved results for a specific category.
  List<SavedAiWaste> getSavedResultsForCategory(String categoryName) {
    return _savedAiResults.where((r) => r.category.toLowerCase() == categoryName.toLowerCase()).toList();
  }
  
  /// Find a saved result by ID.
  SavedAiWaste? findSavedResultById(String id) {
    try {
      return _savedAiResults.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Load saved ids from disk.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefsKey) ?? const [];
      final results = prefs.getStringList(_savedResultsKey) ?? const [];
      final aiResultsJson = prefs.getStringList(_savedAiResultsKey) ?? const [];

      final diskResults = <SavedAiWaste>[];
      for (final jsonStr in aiResultsJson) {
        try {
          final map = json.decode(jsonStr) as Map<String, dynamic>;
          diskResults.add(SavedAiWaste(
            id: (map['id'] ?? '') as String,
            name: (map['name'] ?? '') as String,
            tagalogName: (map['tagalogName'] ?? '') as String,
            category: (map['category'] ?? '') as String,
            confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
            binColor: (map['binColor'] ?? '') as String,
            recyclable: (map['recyclable'] ?? false) as bool,
            icon: (map['icon'] ?? '') as String,
            imageBytes: base64Decode((map['imageBytes'] ?? '') as String),
            imageName: (map['imageName'] ?? '') as String,
            savedAt:
                DateTime.tryParse((map['savedAt'] ?? '') as String) ??
                    DateTime.now(),
          ));
        } catch (_) {
          // Skip a single corrupted record instead of failing the whole load.
        }
      }

      // Keep items that are only in memory (e.g. saved this session but not
      // yet mirrored to disk) so switching to the Saved tab never empties
      // the list right after the user saved something.
      final diskIds = diskResults.map((r) => r.id).toSet();
      final pending =
          _savedAiResults.where((r) => !diskIds.contains(r.id)).toList();

      _savedIds = List.of(ids);
      _savedResultCategories = List.of(results);
      _savedAiResults = [...pending, ...diskResults];
    } catch (_) {
      // Leave current state intact but still mark loaded so the UI can settle.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Save or unsave [item] locally.
  Future<void> toggle(WasteGuideItem item) async {
    if (_savedIds.contains(item.id)) {
      _savedIds.remove(item.id);
    } else {
      _savedIds.add(item.id);
    }
    await _persist();
    notifyListeners();
  }

  /// Save all items under a given category name.
  Future<void> saveCategory(String categoryName) async {
    final cat = WasteGuideData.findCategory(categoryName);
    if (cat == null) return;
    for (final item in cat.items) {
      if (!_savedIds.contains(item.id)) {
        _savedIds.add(item.id);
      }
    }
    await _persist();
    notifyListeners();
  }

  /// Save an AI scan result category (legacy - category name only).
  Future<void> saveResultCategory(String categoryName) async {
    final cat = WasteGuideData.findCategory(categoryName);
    if (cat == null) return;
    _savedResultCategories.remove(categoryName);
    _savedResultCategories.insert(0, cat.name);
    await _persistResults();
    notifyListeners();
  }

  /// Save a full AI scan result with image and all metadata.
  Future<void> saveAiResult(AiWaste result, {required Uint8List imageBytes, required String imageName}) async {
    // Always save, even when the AI label does not map to a known guide
    // category. The detail screen falls back to the bin's basic info.
    final cat = WasteGuideData.findCategory(result.category);
    final savedResult = SavedAiWaste.fromAiWaste(result, imageBytes: imageBytes, imageName: imageName);
    _savedAiResults.insert(0, savedResult);

    // Also update legacy list for backward compatibility (deduplicate names).
    final legacyName = cat?.name ?? (result.category.isEmpty ? savedResult.bin.name : result.category);
    if (!_savedResultCategories.contains(legacyName)) {
      _savedResultCategories.insert(0, legacyName);
    }

    try {
      await _persistAiResults();
      await _persistResults();
    } catch (_) {
      // Keep the result in memory even if disk persistence fails so the
      // Saved page is never empty after an explicit save.
    }
    notifyListeners();
  }

  /// Remove a saved AI result by category.
  Future<void> removeAiResult(String categoryName) async {
    _savedAiResults.removeWhere((r) => r.category.toLowerCase() == categoryName.toLowerCase());
    // Only remove from legacy list if no more results with this category exist
    if (!_savedAiResults.any((r) => r.category.toLowerCase() == categoryName.toLowerCase())) {
      _savedResultCategories.remove(categoryName);
    }
    await _persistAiResults();
    await _persistResults();
    notifyListeners();
  }
  
  /// Remove a specific saved AI result by ID.
  Future<void> removeAiResultById(String id) async {
    final resultIndex = _savedAiResults.indexWhere((r) => r.id == id);
    if (resultIndex == -1) return;
    
    final result = _savedAiResults[resultIndex];
    final categoryName = result.category;
    _savedAiResults.removeAt(resultIndex);
    
    // Only remove from legacy list if no more results with this category exist
    if (!_savedAiResults.any((r) => r.category.toLowerCase() == categoryName.toLowerCase())) {
      _savedResultCategories.remove(categoryName);
    }
    await _persistAiResults();
    await _persistResults();
    notifyListeners();
  }

  /// Remove a saved scan result category (legacy).
  Future<void> removeResultCategory(String categoryName) async {
    _savedResultCategories.remove(categoryName);
    _savedAiResults.removeWhere((r) => r.category.toLowerCase() == categoryName.toLowerCase());
    await _persistResults();
    await _persistAiResults();
    notifyListeners();
  }

  /// Remove a single saved item.
  Future<void> remove(String id) async {
    if (!_savedIds.contains(id)) return;
    _savedIds.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _savedIds);
  }

  Future<void> _persistResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedResultsKey, _savedResultCategories);
  }

  Future<void> _persistAiResults() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _savedAiResults.map((result) {
      return json.encode({
        'id': result.id,
        'name': result.name,
        'tagalogName': result.tagalogName,
        'category': result.category,
        'confidence': result.confidence,
        'binColor': result.binColor,
        'recyclable': result.recyclable,
        'icon': result.icon,
        'imageBytes': base64Encode(result.imageBytes),
        'imageName': result.imageName,
        'savedAt': result.savedAt.toIso8601String(),
      });
    }).toList();
    await prefs.setStringList(_savedAiResultsKey, jsonList);
  }
}
