import 'package:flutter_test/flutter_test.dart';

import 'package:wise/models/waste_bin.dart';
import 'package:wise/models/waste_guide.dart';

void main() {
  group('WasteGuideData.findCategory', () {
    const cases = <String, String>{
      'Biodegradable': 'Biodegradable Waste',
      'Biodegradable Waste': 'Biodegradable Waste',
      'biodegradable': 'Biodegradable Waste',
      'Organic': 'Biodegradable Waste',
      'Electronic Waste': 'Electronic Waste (E-Waste)',
      'E-Waste': 'Electronic Waste (E-Waste)',
      'Electronic': 'Electronic Waste (E-Waste)',
      'E-waste': 'Electronic Waste (E-Waste)',
      'Hazardous': 'Hazardous Waste',
      'Hazardous Waste': 'Hazardous Waste',
      'Toxic': 'Hazardous Waste',
      'Recyclable': 'Recyclable Waste',
      'Recyclable Waste': 'Recyclable Waste',
      'Residual': 'Residual (Non-Recyclable) Waste',
      'Residual (Non-Recyclable) Waste': 'Residual (Non-Recyclable) Waste',
      'Non-Recyclable': 'Residual (Non-Recyclable) Waste',
      'Non-Recyclable Waste': 'Residual (Non-Recyclable) Waste',
      'Non-Biodegradable': 'Residual (Non-Recyclable) Waste',
      'Non-Biodegradable Waste': 'Residual (Non-Recyclable) Waste',
      'General': 'Residual (Non-Recyclable) Waste',
      'Chemical': 'Hazardous Waste',
      'Danger': 'Hazardous Waste',
    };

    cases.forEach((input, expected) {
      test('maps "$input" to "$expected"', () {
        final cat = WasteGuideData.findCategory(input);
        expect(cat, isNotNull, reason: 'no category found for "$input"');
        expect(cat!.name, expected, reason: 'wrong category for "$input"');
      });
    });
  });

  group('WasteBin.forCategory', () {
    const cases = <String, String>{
      'Biodegradable': 'Biodegradable Waste',
      'Biodegradable Waste': 'Biodegradable Waste',
      'biodegradable': 'Biodegradable Waste',
      'Organic': 'Biodegradable Waste',
      'Organic Waste': 'Biodegradable Waste',
      'Compost': 'Biodegradable Waste',
      'Electronic Waste': 'Electronic Waste (E-Waste)',
      'E-Waste': 'Electronic Waste (E-Waste)',
      'Electronic': 'Electronic Waste (E-Waste)',
      'Hazardous': 'Hazardous Waste',
      'Toxic': 'Hazardous Waste',
      'Chemical': 'Hazardous Waste',
      'Recyclable': 'Recyclable Waste',
      'Recyclable Waste': 'Recyclable Waste',
      'Residual': 'Residual Waste',
      'Residual (Non-Recyclable) Waste': 'Residual Waste',
      'Non-Recyclable': 'Residual Waste',
      'Non-Recyclable Waste': 'Residual Waste',
      'Non-Biodegradable': 'Residual Waste',
      'Non-Biodegradable Waste': 'Residual Waste',
    };

    cases.forEach((input, expected) {
      test('maps "$input" to bin "$expected"', () {
        final bin = WasteBin.forCategory(input);
        expect(bin.name, expected, reason: 'wrong bin for "$input"');
      });
    });
  });
}
