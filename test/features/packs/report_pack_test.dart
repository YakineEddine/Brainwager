import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/pack_repository.dart';
import 'package:brainwager/features/packs/report_pack_dialog.dart';
import 'package:brainwager/l10n/app_localizations.dart';

void main() {
  test('S) motif rogné/min/max', () {
    expect(validateReportReason('  okay  '), isNull);
    expect(validateReportReason('ab'), 'invalid-report-reason');
    expect(validateReportReason('   '), 'invalid-report-reason');
    expect(
      validateReportReason(List.filled(501, 'x').join()),
      'invalid-report-reason',
    );
    expect(
      validateReportReason(List.filled(500, 'x').join()),
      isNull,
    );
  });

  test('T) premier signalement parsé', () {
    final r = ReportResult.fromRpc(
        {'reported': true, 'already_reported': false});
    expect(r.reported, isTrue);
    expect(r.alreadyReported, isFalse);
  });

  test('U) doublon parsé', () {
    final r = ReportResult.fromRpc(
        {'reported': true, 'already_reported': true});
    expect(r.reported, isTrue);
    expect(r.alreadyReported, isTrue);
  });

  testWidgets('X) dialogue arabe RTL localisé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
            Locale('ar'),
          ],
          home: const ReportPackDialog(packId: 'p1'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('الإبلاغ عن الحزمة'), findsOneWidget);
    expect(find.text('السبب'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });
}
