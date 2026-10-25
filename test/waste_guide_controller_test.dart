import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wise/controllers/waste_guide_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load() always finishes and skips corrupted saved records', () async {
    final valid = {
      'id': 'saved_1',
      'name': 'Banana Peel',
      'tagalogName': '',
      'category': 'Biodegradable Waste',
      'confidence': 0.95,
      'binColor': '',
      'recyclable': false,
      'icon': '',
      'imageBytes': 'aGVsbG8=',
      'imageName': 'waste.jpg',
      'savedAt': DateTime(2026, 1, 1).toIso8601String(),
    };

    SharedPreferences.setMockInitialValues({
      'saved_ai_results_v1': <String>[
        'not valid json {',
        jsonEncode(valid),
      ],
    });
    WasteGuideController.instance.clearForTest();

    final controller = WasteGuideController.instance;
    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.savedAiResults.length, 1);
    expect(controller.savedAiResults.first.category, 'Biodegradable Waste');
  });

  test('load() finishes when no data is stored', () async {
    SharedPreferences.setMockInitialValues({});
    WasteGuideController.instance.clearForTest();

    final controller = WasteGuideController.instance;
    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.savedAiResults, isEmpty);
  });
}
