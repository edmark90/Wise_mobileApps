import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wise/controllers/waste_guide_controller.dart';
import 'package:wise/models/ai_waste.dart';
import 'package:wise/screens/WasteGuideScreen.dart';

// A minimal valid 1x1 PNG so Image.memory has real pixels to decode.
final Uint8List validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Saved tab shows a scan that was just saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = WasteGuideController.instance;
    controller.clearForTest();
    await controller.load();

    await controller.saveAiResult(
      AiWaste(
        name: 'Banana Peel',
        tagalogName: 'Balat ng Saging',
        category: 'Biodegradable Waste',
        confidence: 0.95,
        binColor: '',
        recyclable: false,
        icon: '',
      ),
      imageBytes: validPng,
      imageName: 'waste.png',
    );
    controller.setSelectedCategory('Biodegradable Waste');

    await tester.pumpWidget(const MaterialApp(home: WasteGuideScreen()));
    await tester.pumpAndSettle();

    // The Saved sub-tab should be active (a category was selected).
    expect(find.text('1 Saved Scan'), findsOneWidget);
    expect(find.text('Biodegradable Waste'), findsWidgets);
    expect(find.text('No Saved Scans Yet'), findsNothing);
  });
}
