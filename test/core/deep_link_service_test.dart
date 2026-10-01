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
}
