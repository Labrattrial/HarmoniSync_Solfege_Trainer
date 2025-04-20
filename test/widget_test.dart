import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_detector/screens/pitch_detector_screen.dart';

void main() {
  testWidgets('PitchDetectorScreen UI elements load correctly', (WidgetTester tester) async {
    // Load the widget
    await tester.pumpWidget(const MaterialApp(home: PitchDetectorScreen()));

    // Check for pitch text
    expect(find.textContaining('Detected Pitch'), findsOneWidget);

    // Check for the start/stop button
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
