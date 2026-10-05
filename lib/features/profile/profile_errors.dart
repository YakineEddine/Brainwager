// Erreurs profil conviviales FR/EN/AR (codes, jamais de brut).
// L'appelant transmet la langue UI via AppLocalizations.
import '../../l10n/app_localizations.dart';

String friendlyProfileError(
  String code,
  AppLocalizations l10n, {
  String? fallback,
}) {
  switch (code) {
    case 'invalid-display-name':
      return l10n.invalidDisplayName;
    case 'avatar-locked-or-invalid':
      return l10n.avatarLocked;
    case 'oauth-unavailable':
      return l10n.oauthUnavailable;
    case 'profile-not-found':
    case 'not-authenticated':
      return l10n.profileLoadError;
    default:
      return fallback ?? l10n.profileSaveError;
  }
}
