// Basic smoke test — the counter-app template test no longer applies
// since WoodlandsTrailGuideApp replaced MyApp. This just verifies the
// app boots without throwing and the tab bar renders.

import 'package:flutter_test/flutter_test.dart';

import 'package:woodlandstrailguide_flutter/main.dart';

void main() {
  testWidgets('App boots and shows the tab bar', (WidgetTester tester) async {
    await tester.pumpWidget(const WoodlandsTrailGuideApp());
    await tester.pump();

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Trails'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
