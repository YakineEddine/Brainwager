// Panneau actions hôte Phase UI-2 : hiérarchie claire (progression vs
// final). La VISIBILITÉ reste pilotée par l'appelant via les prédicats
// existants (showLockFor/showRevealFor/...) : ce widget ne fait que
// présenter. Finale (Finish) visuellement distincte (corail).
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/brain_buttons.dart';
import '../../../shared/widgets/brain_card.dart';

class BrainHostControls extends StatelessWidget {
  final bool showLock;
  final String lockLabel;
  final VoidCallback onLock;
  final bool showReveal;
  final String revealLabel;
  final VoidCallback onReveal;
  final bool showBoard;
  final String boardLabel;
  final VoidCallback onBoard;
  final bool showNext;
  final String nextLabel;
  final VoidCallback onNext;
  final bool showFinish;
  final String finishLabel;
  final VoidCallback onFinish;
  const BrainHostControls({
    super.key,
    required this.showLock,
    required this.lockLabel,
    required this.onLock,
    required this.showReveal,
    required this.revealLabel,
    required this.onReveal,
    required this.showBoard,
    required this.boardLabel,
    required this.onBoard,
    required this.showNext,
    required this.nextLabel,
    required this.onNext,
    required this.showFinish,
    required this.finishLabel,
    required this.onFinish,
  });

  /// Vrai si au moins une action est visible (panneau affichable).
  bool get hasVisible =>
      showLock || showReveal || showBoard || showNext || showFinish;

  @override
  Widget build(BuildContext context) {
    if (!hasVisible) return const SizedBox.shrink();
    return BrainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLock) ...[
            BrainPrimaryButton(
              onPressed: onLock,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock),
                  const SizedBox(width: BrainSpacing.sm),
                  Text(lockLabel),
                ],
              ),
            ),
          ],
          if (showReveal) ...[
            if (showLock) const SizedBox(height: BrainSpacing.sm),
            BrainPrimaryButton(
              onPressed: onReveal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility),
                  const SizedBox(width: BrainSpacing.sm),
                  Text(revealLabel),
                ],
              ),
            ),
          ],
          if (showBoard) ...[
            if (showLock || showReveal) const SizedBox(height: BrainSpacing.sm),
            BrainSecondaryButton(
              onPressed: onBoard,
              expanded: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.leaderboard),
                  const SizedBox(width: BrainSpacing.sm),
                  Text(boardLabel),
                ],
              ),
            ),
          ],
          if (showNext) ...[
            if (showLock || showReveal || showBoard)
              const SizedBox(height: BrainSpacing.sm),
            BrainSecondaryButton(
              onPressed: onNext,
              expanded: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.skip_next),
                  const SizedBox(width: BrainSpacing.sm),
                  Text(nextLabel),
                ],
              ),
            ),
          ],
          if (showFinish) ...[
            if (showLock || showReveal || showBoard || showNext)
              const SizedBox(height: BrainSpacing.sm),
            ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrainColors.coral,
                foregroundColor: BrainColors.deepBackground,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events),
                  const SizedBox(width: BrainSpacing.sm),
                  Text(finishLabel),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
