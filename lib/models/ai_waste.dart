import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'waste_bin.dart';

/// Result of an AI waste classification returned by the backend.
class AiWaste {
  final String name;
  final String tagalogName;
  final String category;
  final double confidence;
  final String binColor;
  final bool recyclable;
  final String icon;

  const AiWaste({
    this.name = '',
    this.tagalogName = '',
    this.category = '',
    this.confidence = 0,
    this.binColor = '',
    this.recyclable = false,
    this.icon = '',
  });

  factory AiWaste.fromJson(Map<String, dynamic> json) {
    final rawCategory = (json['category'] ?? json['prediction'] ?? 'Unknown Waste').toString();
    
    // Debug logging to see what AI returns
    debugPrint('AI Response - Category: $rawCategory');
    debugPrint('AI Response - Full JSON: $json');
    
    final bin = WasteBin.forCategory(rawCategory);

    final rawName = (json['name'] ?? rawCategory).toString();
    final rawTagalogName = (json['tagalog_name'] ?? json['sub_category'] ?? bin.tagalog).toString();

    // Confidence can be 0..1 scale (e.g. 0.96) or 0..100 scale (e.g. 96.5)
    double rawConfidence = 0.0;
    final confVal = json['confidence'];
    if (confVal is num) {
      rawConfidence = confVal.toDouble();
      if (rawConfidence > 1.0) {
        rawConfidence = rawConfidence / 100.0;
      }
    }

    final isRecyclable = json.containsKey('recyclable')
        ? (json['recyclable'] == true)
        : (bin == WasteBin.recyclable);

    final iconStr = (json['icon'] ?? '').toString().isNotEmpty
        ? (json['icon'] ?? '').toString()
        : bin.emoji;

    final colorStr = (json['bin_color'] ?? '').toString().isNotEmpty
        ? (json['bin_color'] ?? '').toString()
        : bin.name;

    debugPrint('Matched Bin: ${bin.name} (${bin.color})');

    return AiWaste(
      name: rawName,
      tagalogName: rawTagalogName,
      category: rawCategory,
      confidence: rawConfidence.clamp(0.0, 1.0),
      binColor: colorStr,
      recyclable: isRecyclable,
      icon: iconStr,
    );
  }

  /// Confidence as a 0–100 integer for display.
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  /// Standard bin for the returned [category].
  WasteBin get bin => WasteBin.forCategory(category);

  /// Resolved color for the prediction header/band.
  Color get reportedBinColor => bin.color;
}

/// Saved AI waste result with image and metadata for local storage.
class SavedAiWaste {
  final String id;
  final String name;
  final String tagalogName;
  final String category;
  final double confidence;
  final String binColor;
  final bool recyclable;
  final String icon;
  final Uint8List imageBytes;
  final String imageName;
  final DateTime savedAt;

  const SavedAiWaste({
    required this.id,
    required this.name,
    required this.tagalogName,
    required this.category,
    required this.confidence,
    required this.binColor,
    required this.recyclable,
    required this.icon,
    required this.imageBytes,
    required this.imageName,
    required this.savedAt,
  });

  factory SavedAiWaste.fromAiWaste(AiWaste result, {required Uint8List imageBytes, required String imageName}) {
    return SavedAiWaste(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      name: result.name,
      tagalogName: result.tagalogName,
      category: result.category.isEmpty ? result.bin.name : result.category,
      confidence: result.confidence,
      binColor: result.binColor,
      recyclable: result.recyclable,
      icon: result.icon,
      imageBytes: imageBytes,
      imageName: imageName,
      savedAt: DateTime.now(),
    );
  }

  /// Convert to AiWaste for compatibility.
  AiWaste toAiWaste() => AiWaste(
    name: name,
    tagalogName: tagalogName,
    category: category,
    confidence: confidence,
    binColor: binColor,
    recyclable: recyclable,
    icon: icon,
  );

  /// Confidence as a 0–100 integer for display.
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  /// Standard bin for the returned [category].
  WasteBin get bin => WasteBin.forCategory(category);

  /// Resolved color for the prediction header/band.
  Color get reportedBinColor => bin.color;
}

