import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/main.dart';

void main() {
  testWidgets(
      'L) shell bootstrap en ar : message arabe + RTL', (tester) async {
    await tester.pumpWidget(
      const BrainwagerApp(
        initError: 'boom',
        locale: Locale('ar'),
      ),
    );
    await tester.pump();
    expect(find.text('تعذر تشغيل Brainwager.'), findsOneWidget);
    // Détail technique conservé pour le debug.
    expect(find.text('boom'), findsOneWidget);
    expect(
      tester.widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });
}
