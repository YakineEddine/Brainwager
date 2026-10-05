// Gate onboarding au niveau app : entoure le contenu du router.
// - chargement profil => état compact
// - session + onboarding_complete=false => OnboardingScreen plein écran
//   (SANS navbar, la localisation router sous-jacente est préservée)
// - onboarding_complete=true (ou erreur sans profil => retry) => enfant.
// Ne détruit jamais la localisation go_router : l'enfant reste monté dans
// l'arbre dès que la gate s'ouvre.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import 'onboarding_screen.dart';
import 'profile_controller.dart';
import 'profile_errors.dart';

class OnboardingGate extends ConsumerStatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    if (state.profileLoading && state.profile == null) {
      return const BrainScaffold(body: BrainLoading());
    }
    final profile = state.profile;
    if (profile != null && !profile.onboardingComplete) {
      return const OnboardingScreen();
    }
    if (profile == null && state.profileError != null) {
      return BrainScaffold(
        body: BrainError(
          message: friendlyProfileError(state.profileError!, l10n),
          onRetry: () => controller.reloadAll(),
          retryLabel: l10n.retry,
        ),
      );
    }
    return widget.child;
  }
}
