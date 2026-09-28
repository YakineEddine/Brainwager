import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/shared/widgets/countdown_ring.dart';

Future<void> _pumpRing(
  WidgetTester tester, {
  required int remainingSec,
  required int durationSec,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CountdownRing(
          remainingSec: remainingSec,
          durationSec: durationSec,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche le restant puis zéro après rebuild', (tester) async {
    await _pumpRing(tester, remainingSec: 12, durationSec: 30);
    expect(find.text('12 s'), findsOneWidget);
    await _pumpRing(tester, remainingSec: 0, durationSec: 30);
    await tester.pump();
    expect(find.text('0 s'), findsOneWidget);
  });

  testWidgets('restant négatif clampé, durée nulle sans crash', (tester) async {
    await _pumpRing(tester, remainingSec: -4, durationSec: 30);
    expect(find.text('0 s'), findsOneWidget);
    await _pumpRing(tester, remainingSec: 0, durationSec: 0);
    await tester.pump();
    expect(find.text('0 s'), findsOneWidget);
  });
}
