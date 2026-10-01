import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/navigation/deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('F) double start sans double abonnement ni crash', () async {
    final service = DeepLinkService();
    var calls = 0;
    await service.start((_) => calls++);
    expect(service.isStarted, isTrue);
    await service.start((_) => calls++);
    expect(service.isStarted, isTrue);
    // Aucun lien émis headless : zéro navigation parasite.
    expect(calls, 0);
    await service.dispose();
    expect(service.isStarted, isFalse);
    // Redémarrage propre après dispose.
    await service.start((_) => calls++);
    expect(service.isStarted, isTrue);
    await service.dispose();
  });

  test('vrai URI émis une seule fois, malformé ignoré', () async {
    final controller = StreamController<Uri>();
    final service = DeepLinkService(incoming: controller.stream);
    final routes = <String>[];
    await service.start(routes.add);
    await service.start(routes.add); // Second start : pas de doublon.
    controller.add(Uri.parse('brainwager://pack/PK-AB12'));
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/packs/shared/PK-AB12']);
    controller.add(Uri.parse('brainwager://pack/bad'));
    await Future<void>.delayed(Duration.zero);
    expect(routes, ['/packs/shared/PK-AB12']);
    await service.dispose();
    await controller.close();
  });
}
