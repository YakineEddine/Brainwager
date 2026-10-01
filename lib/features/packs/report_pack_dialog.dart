// Dialogue de signalement Phase 3D : raison 3..500, RPC report_pack only.
// Réutilisé par le détail partagé (non possédé) et le détail catalogue.
// Aucun compteur incrémenté côté client, aucun masquage local.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import 'pack_repository.dart';

class ReportPackDialog extends ConsumerStatefulWidget {
  final String packId;
  const ReportPackDialog({super.key, required this.packId});

  @override
  ConsumerState<ReportPackDialog> createState() => _ReportPackDialogState();
}

/// Motif valide ? Pur : 3..500 caractères rognés (miroir serveur).
/// Retourne null si valide, sinon le code d'erreur.
String? validateReportReason(String reason) {
  final r = reason.trim();
  if (r.length < 3 || r.length > 500) return 'invalid-report-reason';
  return null;
}

class _ReportPackDialogState extends ConsumerState<ReportPackDialog> {
  final _reason = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _done = false;
  bool _already = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _lang() => Localizations.localeOf(context).languageCode;

  Future<void> _send() async {
    if (_sending) return;
    final reason = _reason.text;
    final invalid = validateReportReason(reason);
    if (invalid != null) {
      setState(() {
        _error = friendlyUgcError(invalid, _lang());
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await PackRepository().reportPack(widget.packId, reason);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = true;
        _already = res.alreadyReported;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyUgcError(e, _lang());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.reportPackTitle),
      content: _done
          ? Text(_already ? l10n.reportUpdated : l10n.packReported)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _reason,
                  enabled: !_sending,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.reportReason),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!),
                ],
              ],
            ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.reportCancel),
          ),
        if (!_done)
          ElevatedButton(
            onPressed: _sending ? null : _send,
            child: Text(l10n.reportSend),
          ),
        if (_done)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reportClose),
          ),
      ],
    );
  }
}

/// Ouvre le dialogue ; retourne true si un signalement a abouti.
Future<bool> showReportPackDialog(BuildContext context, String packId) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => ReportPackDialog(packId: packId),
  );
  return res ?? false;
}
