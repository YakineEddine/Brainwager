// Régression géométrie BrainScaffold : le body démarre SOUS l'AppBar
// (jamais de chevauchement), et reste SafeArea-protégé sans AppBar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/shared/widgets/brain_scaffold.dart';

void main() {
  testWidgets('avec AppBar : le body commence sous l’AppBar', (tester) async {
    const topKey = Key('body-top');
    await tester.pumpWidget(
      MaterialApp(
        home: BrainScaffold(
          appBar: AppBar(title: Text('Title')),
          body: Column(
            children: [
              SizedBox(key: topKey, height: 10, width: double.infinity),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    final bodyTop = tester.getRect(find.byKey(topKey)).top;
    expect(bodyTop, greaterThanOrEqualTo(appBarBottom));
  });

  testWidgets('sans AppBar : le body respecte la SafeArea système', (
    tester,
  ) async {
    const topKey = Key('body-top');
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: MaterialApp(
          home: BrainScaffold(
            body: Column(
              children: [
                SizedBox(key: topKey, height: 10, width: double.infinity),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bodyTop = tester.getRect(find.byKey(topKey)).top;
    expect(bodyTop, greaterThanOrEqualTo(44));
  });
}
