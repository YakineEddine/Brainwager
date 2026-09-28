import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/network/heartbeat.dart';

void main() {
  test('beat immédiat puis périodique', () {
    FakeAsync().run((fa) {
      var calls = 0;
      final hb = GameHeartbeat(
        onBeat: () async => calls++,
        interval: const Duration(seconds: 15),
      );
      hb.start();
      fa.flushMicrotasks();
      expect(calls, 1);
      expect(hb.isRunning, isTrue);
      fa.elapse(const Duration(seconds: 15));
      fa.flushMicrotasks();
      expect(calls, 2);
      hb.dispose();
    });
  });

  test('stop annule proprement, double start sans doublon', () {
    FakeAsync().run((fa) {
      var calls = 0;
      final hb = GameHeartbeat(
        onBeat: () async => calls++,
        interval: const Duration(seconds: 15),
      );
      hb.start();
      hb.start(); // Sans effet : un seul timer.
      fa.flushMicrotasks();
      expect(calls, 1);
      hb.stop();
      expect(hb.isRunning, isFalse);
      fa.elapse(const Duration(minutes: 5));
      fa.flushMicrotasks();
      expect(calls, 1);
      hb.dispose();
    });
  });

  test('pas de chevauchement quand un beat dépasse l’intervalle', () {
    FakeAsync().run((fa) {
      var calls = 0;
      var concurrent = 0;
      var maxConcurrent = 0;
      final hb = GameHeartbeat(
        onBeat: () async {
          calls++;
          concurrent++;
          maxConcurrent = max(maxConcurrent, concurrent);
          await Future.delayed(const Duration(seconds: 30));
          concurrent--;
        },
        interval: const Duration(seconds: 15),
      );
      hb.start();
      fa.elapse(const Duration(minutes: 5));
      fa.flushMicrotasks();
      expect(maxConcurrent, 1);
      expect(calls, greaterThan(1));
      hb.dispose();
    });
  });

  test('échec réseau toléré : erreur mémorisée, timer conservé', () {
    FakeAsync().run((fa) {
      var calls = 0;
      final hb = GameHeartbeat(
        onBeat: () async {
          calls++;
          throw StateError('réseau coupé');
        },
        interval: const Duration(seconds: 15),
      );
      hb.start();
      fa.flushMicrotasks();
      expect(calls, 1);
      expect(hb.lastError, isStateError);
      expect(hb.lastOkAt, isNull);
      fa.elapse(const Duration(seconds: 15));
      fa.flushMicrotasks();
      expect(calls, 2); // Le timer continue malgré l’échec.
      hb.dispose();
    });
  });

  test('dispose bloque tout démarrage ultérieur', () {
    FakeAsync().run((fa) {
      var calls = 0;
      final hb = GameHeartbeat(
        onBeat: () async => calls++,
        interval: const Duration(seconds: 15),
      );
      hb.dispose();
      hb.start();
      fa.elapse(const Duration(minutes: 1));
      fa.flushMicrotasks();
      expect(calls, 0);
      expect(hb.isRunning, isFalse);
    });
  });
}
