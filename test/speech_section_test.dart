import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wise/widgets/common/speech_section.dart';

void main() {
  testWidgets('SpeechReader renders sections with one TTS button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SpeechReader(
          sections: [
            SpeechText(
              title: 'Description',
              text: 'This is the example description.',
              icon: Icons.description_rounded,
              color: Colors.green,
            ),
            SpeechText(
              title: 'Proper Disposal',
              text: 'Please dispose this properly.',
              icon: Icons.check_circle_rounded,
              color: Colors.blue,
            ),
            SpeechText(
              title: "Don't Do",
              text: 'Never burn this waste.',
              icon: Icons.cancel_rounded,
              color: Colors.red,
            ),
          ],
        ),
      ),
    ));

    expect(find.text('Text to Speech'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Proper Disposal'), findsOneWidget);
    expect(find.text("Don't Do"), findsOneWidget);
    expect(find.textContaining('example description'), findsOneWidget);
    expect(find.textContaining('dispose this properly'), findsOneWidget);
    expect(find.textContaining('Never burn this waste'), findsOneWidget);
  });
}
