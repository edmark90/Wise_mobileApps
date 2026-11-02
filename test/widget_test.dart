import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wise/main.dart';
import 'package:wise/screens/Login.dart';
import 'package:wise/screens/Signup.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders login screen with modern branding and elements', (WidgetTester tester) async {
    await tester.pumpWidget(const WasteWiseApp());
    await tester.pumpAndSettle();

    // Verify the login screen is shown
    expect(find.text('WasteWise'), findsOneWidget);
    expect(find.text('Smart Waste Management'), findsOneWidget);
    expect(find.text('City of Muntinlupa'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Need help signing in?'), findsOneWidget);
  });

  testWidgets('Login screen help dialog opens and closes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Need help signing in?'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In Help'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In Help'), findsNothing);
  });

  testWidgets('Login shows validation error when submitting empty fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter both email and password'), findsOneWidget);
  });

  testWidgets('App navigates to signup screen and renders form sections', (WidgetTester tester) async {
    await tester.pumpWidget(const WasteWiseApp());
    await tester.pumpAndSettle();

    // Scroll until Sign Up is visible and tap it
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    // Verify signup screen elements
    expect(find.text('Join WasteWise'), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('PERSONAL DETAILS'), findsOneWidget);
    expect(find.text('RESIDENTIAL LOCATION'), findsOneWidget);
    expect(find.text('ACCOUNT SECURITY'), findsOneWidget);
    expect(find.text('Barangay'), findsOneWidget);
  });

  testWidgets('Signup shows validation error on empty submit', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Please fill in all required fields'), findsOneWidget);
  });

  testWidgets('Signup opens barangay picker, filters and selects', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to barangay picker and tap
    await tester.ensureVisible(find.text('Select your Barangay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select your Barangay'));
    await tester.pumpAndSettle();

    // Modal sheet header and first item
    expect(find.text('Select Your Barangay'), findsOneWidget);
    expect(find.text('Alabang'), findsOneWidget);

    // Search Putatan
    final searchInput = find.widgetWithText(TextField, 'Search barangay name...');
    expect(searchInput, findsOneWidget);
    await tester.enterText(searchInput, 'Puta');
    await tester.pumpAndSettle();

    expect(find.text('Putatan'), findsOneWidget);
    expect(find.text('Alabang'), findsNothing);

    // Tap Putatan
    await tester.tap(find.text('Putatan'));
    await tester.pumpAndSettle();

    // Modal closes, Putatan is selected
    expect(find.text('Select Your Barangay'), findsNothing);
    expect(find.text('Putatan'), findsOneWidget);
    expect(find.text('Muntinlupa City, Metro Manila'), findsOneWidget);
  });

  testWidgets('Signup live password indicator validates length and matching', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    final passwordField = textFields.at(3);
    final confirmField = textFields.at(4);

    await tester.ensureVisible(passwordField);
    await tester.pumpAndSettle();

    // Type short password
    await tester.enterText(passwordField, 'short');
    await tester.pumpAndSettle();
    expect(find.text('Minimum 8 characters'), findsOneWidget);

    // Type valid password
    await tester.enterText(passwordField, 'securePass88');
    await tester.pumpAndSettle();
    expect(find.text('Minimum 8 characters'), findsOneWidget);

    // Type non-matching confirm
    await tester.ensureVisible(confirmField);
    await tester.pumpAndSettle();
    await tester.enterText(confirmField, 'mismatch');
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match yet'), findsOneWidget);

    // Type matching confirm
    await tester.enterText(confirmField, 'securePass88');
    await tester.pumpAndSettle();
    expect(find.text('Passwords match'), findsOneWidget);
  });

  testWidgets('Login validates email format', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'invalidemailformat');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('Signup validates email format and password matching on submit', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Maria Santos');
    await tester.enterText(textFields.at(1), 'notanemail');
    await tester.enterText(textFields.at(3), 'validPass123');
    await tester.enterText(textFields.at(4), 'validPass123');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('Signup barangay search clear button resets filter', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Select your Barangay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select your Barangay'));
    await tester.pumpAndSettle();

    final searchInput = find.widgetWithText(TextField, 'Search barangay name...');
    await tester.enterText(searchInput, 'Cup');
    await tester.pumpAndSettle();

    expect(find.text('Cupang'), findsOneWidget);
    expect(find.text('Alabang'), findsNothing);

    // Tap clear button in search field
    final clearButton = find.byIcon(Icons.clear_rounded);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // All barangays visible again
    expect(find.text('Alabang'), findsOneWidget);
    expect(find.text('Cupang'), findsOneWidget);
  });

  testWidgets('Login password visibility toggle switches obscure state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial obscureText is true on password field
    final textFields = find.byType(TextField);
    final passwordField = tester.widget<TextField>(textFields.at(1));
    expect(passwordField.obscureText, isTrue);

    // Tap visibility toggle
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    // Obscure text should now be false
    final updatedField = tester.widget<TextField>(textFields.at(1));
    expect(updatedField.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
