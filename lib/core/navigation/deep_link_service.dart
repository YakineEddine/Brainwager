// Intégration AppLinks (une seule instance, démarrée une fois depuis
// main) : lien initial + flux en cours d'exécution, routés vers le
// parseur pur puis le callback de navigation (go_router global câblé
// dans main, jamais dans le parseur). Abonnement unique, dispose sûr.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'deep_link_parser.dart';

class DeepLinkService {
  final AppLinks _links;
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  DeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  Future<void> start(void Function(String route) onRoute) async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        final route = parseBrainwagerLink(initial);
        if (route != null) onRoute(route);
      }
    } catch (_) {
      // Pas de lien initial : démarrage normal.
    }
    _subscription = _links.uriLinkStream.listen(
      (uri) {
        final route = parseBrainwagerLink(uri);
        if (route != null) onRoute(route);
      },
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
