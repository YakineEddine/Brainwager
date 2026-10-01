// Intégration AppLinks (une seule instance retained, démarrée une fois
// depuis main) : SEULE source = uriLinkStream (qui délivre aussi l'event
// initial/cold-start, sans double via getInitialLink). Parseur pur puis
// callback de navigation. Abonnement unique, dispose sûr.
import 'dart:async';

import 'package:app_links/app_links.dart';

import 'deep_link_parser.dart';

class DeepLinkService {
  final AppLinks _links;
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  DeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  bool get isStarted => _started;

  Future<void> start(void Function(String route) onRoute) async {
    if (_started) return;
    _started = true;
    _subscription = _links.uriLinkStream.listen((uri) {
      final route = parseBrainwagerLink(uri);
      if (route != null) onRoute(route);
    }, onError: (_) {});
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
