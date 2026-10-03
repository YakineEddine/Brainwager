// Import manuel Phase 3D (/packs/import) : saisie PK-XXXX, résolution via
// get_pack_by_share_code uniquement, puis navigation vers le détail partagé
// par CODE (jamais par UUID : le code est l'autorité pour create_game).
// Sémantique : lookup/use, PAS de copie ni de persistance locale.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_buttons.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import 'shared_pack.dart';

class PackImportScreen extends ConsumerStatefulWidget {
  const PackImportScreen({super.key});

  @override
  ConsumerState<PackImportScreen> createState() => _PackImportScreenState();
}

class _PackImportScreenState extends ConsumerState<PackImportScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _lang() => Localizations.localeOf(context).languageCode;

  Future<void> _open() async {
    final normalized = normalizePackShareCode(_code.text);
    if (!isValidShareCode(normalized)) {
      setState(() {
        _error = friendlyUgcError('invalid-share-code', _lang());
      });
      return;
    }
    // Pas de pré-validation réseau ici : l'écran partagé charge via le RPC
    // (même chemin que les deep links) avec ses états loading/erreur/retry.
    if (!mounted) return;
    context.go('/packs/shared/$normalized');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BrainScaffold(
      appBar: AppBar(title: Text(l10n.packImport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _code,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l10n.packShareCode),
                  onSubmitted: (_) => _open(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrainPrimaryButton(onPressed: _open, child: Text(l10n.packOpen)),
        ],
      ),
    );
  }
}
