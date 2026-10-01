// Intégration AppLinks (une seule instance retained, démarrée une fois
// depuis main) : SEULE source = uriLinkStream (qui délivre aussi l'event
// initial/cold-start, sans double via getInitialLink). Parseur pur puis
// callback de navigation. Abonnement unique, dispose sûr.
import 'dart:async';

import 'package:app_links/app_links.dart';

import 'deep_link_parser.dart';

class DeepLinkService {
  final AppLinks? _links;

  /// Flux injecté pour les tests uniquement. En production : null et le
  /// service utilise AppLinks().uriLinkStream (seule source, sans doublon
  /// via getInitialLink).
  final Stream<Uri>? _incoming;
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  DeepLinkService({AppLinks? links, Stream<Uri>? incoming})
      : _links = links ?? (incoming == null ? AppLinks() : null),
        _incoming = incoming;

  bool get isStarted => _started;

  Future<void> start(void Function(String route) onRoute) async {
    if (_started) return;
    _started = true;
    final stream = _incoming ?? _links!.uriLinkStream;
    _subscription = stream.listen((uri) {
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
