import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wise/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    // Provide an in-memory SharedPreferences store so the session restore
    // (AuthController.restoreSession) works in the test environment.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const WasteWiseApp());
    await tester.pumpAndSettle();

    // Verify the login screen is shown
    expect(find.text('WasteWise'), findsOneWidget);
    expect(find.text('Smart Waste Management'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
