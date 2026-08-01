import 'package:flutter_test/flutter_test.dart';

import 'package:wise/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WasteWiseApp());

    // Verify the login screen is shown
    expect(find.text('WasteWise'), findsOneWidget);
    expect(find.text('Smart Waste Management'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
