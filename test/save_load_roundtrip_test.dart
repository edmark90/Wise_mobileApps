import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wise/controllers/waste_guide_controller.dart';
import 'package:wise/models/ai_waste.dart';

Future<void> resetController() async {
  // Reset the singleton to a fresh app session before each test.
  SharedPreferences.setMockInitialValues({});
  WasteGuideController.instance.clearForTest();
  await WasteGuideController.instance.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save -> load round trip keeps the result', () async {
    await resetController();
    final controller = WasteGuideController.instance;

    final result = AiWaste(
      name: 'Banana Peel',
      tagalogName: 'Balat ng Saging',
      category: 'Biodegradable Waste',
      confidence: 0.95,
      binColor: '',
      recyclable: false,
      icon: '',
    );

    await controller.saveAiResult(
      result,
      imageBytes: Uint8List.fromList([1, 2, 3]),
      imageName: 'waste.jpg',
    );

    expect(controller.savedAiResults.length, 1,
        reason: 'result should be in memory after save');

    // Simulate app restart by reloading from storage.
    await controller.load();
    expect(controller.savedAiResults.length, 1,
        reason: 'result should survive a reload from storage');
    expect(controller.savedAiResults.first.category, 'Biodegradable Waste');
  });

  test('unrecognized AI label is still saved (never silently dropped)',
      () async {
    await resetController();
    final controller = WasteGuideController.instance;

    final result = AiWaste(
      name: 'Plastic Bottle',
      tagalogName: '',
      category: 'Plastic Bottle',
      confidence: 0.88,
      binColor: '',
      recyclable: true,
      icon: '',
    );

    await controller.saveAiResult(
      result,
      imageBytes: Uint8List.fromList([9, 8, 7]),
      imageName: 'waste.jpg',
    );

    expect(controller.savedAiResults.length, 1,
        reason: 'an unmapped label must still appear on the Saved page');
    expect(controller.savedAiResults.first.category, 'Plastic Bottle');
  });

  test('empty category falls back to the bin name label', () async {
    await resetController();
    final controller = WasteGuideController.instance;

    final result = AiWaste(
      name: 'Something',
      tagalogName: '',
      category: '',
      confidence: 0.5,
      binColor: '',
      recyclable: false,
      icon: '',
    );

    await controller.saveAiResult(
      result,
      imageBytes: Uint8List.fromList([1]),
      imageName: 'waste.jpg',
    );

    expect(controller.savedAiResults.length, 1);
    expect(controller.savedAiResults.first.category, isNotEmpty);
  });

  test('save then reload does not wipe an item that disk did not store',
      () async {
    // Simulate the real runtime flow:
    // 1. save adds the item to memory
    // 2. switching tabs triggers load() which reads from disk
    // If the disk write did not land (or a record is transient), the Saved
    // tab must still keep the just-saved item instead of becoming empty.
    await resetController();
    final controller = WasteGuideController.instance;

    await controller.saveAiResult(
      AiWaste(
        name: 'Banana Peel',
        tagalogName: '',
        category: 'Biodegradable Waste',
        confidence: 0.9,
        binColor: '',
        recyclable: false,
        icon: '',
      ),
      imageBytes: Uint8List.fromList([5, 6, 7]),
      imageName: 'waste.jpg',
    );
    expect(controller.savedAiResults.length, 1);

    // Disk currently reports nothing stored for this record.
    SharedPreferences.setMockInitialValues({});
    await controller.load();

    expect(controller.savedAiResults.isNotEmpty, isTrue,
        reason: 'reloading must not wipe the item saved in this session');
  });
}
