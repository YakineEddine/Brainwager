// Timer de partie Phase UI-2 : phases visuelles autour du temps AUTORITATIF.
// Le calcul remainingSec reste 100 % serveur (opened_at + offset) : ce widget
// ne fait que présenter (couleur/emphasis). Aucune logique de durée ici.
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Phases visuelles : >10 s normal, <=10 s avertissement, <=5 s critique.
enum TimerPhase { normal, warning, critical }

TimerPhase timerPhaseFor(int remainingSec) {
  if (remainingSec <= 5) return TimerPhase.critical;
  if (remainingSec <= 10) return TimerPhase.warning;
  return TimerPhase.normal;
}

Color timerPhaseColor(TimerPhase phase) {
  switch (phase) {
    case TimerPhase.normal:
      return BrainColors.turquoise;
    case TimerPhase.warning:
      return BrainColors.gold;
    case TimerPhase.critical:
      return BrainColors.coral;
  }
}

/// Anneau timer premium : taille généreuse, couleur de phase, pulsation
/// lente et douce en critique (scale, jamais de flash).
/// [active] = false après la fin de la question : affichage figé/terminé
/// (aucune pulsation), purement visuel — le temps autoritatif ne change pas.
class BrainTimer extends StatelessWidget {
  final int remainingSec;
  final int durationSec;
  final bool active;
  const BrainTimer({
    super.key,
    required this.remainingSec,
    required this.durationSec,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = remainingSec < 0 ? 0 : remainingSec;
    final progress = durationSec <= 0
        ? 0.0
        : (remaining / durationSec).clamp(0.0, 1.0);
    final phase = active ? timerPhaseFor(remaining) : TimerPhase.critical;
    final color = active ? timerPhaseColor(phase) : BrainColors.textSecondary;
    final ring = SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            color: color,
            backgroundColor: BrainColors.surfaceHigh,
            strokeWidth: phase == TimerPhase.normal && active ? 7 : 9,
          ),
          Text(
            '$remaining s',
            style: TextStyle(
              fontSize: phase == TimerPhase.critical && active ? 22 : 19,
              fontWeight: FontWeight.w800,
              color: BrainColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    if (!active || phase != TimerPhase.critical) return ring;
    return _CriticalPulse(color: color, child: ring);
  }
}

/// Pulsation critique : scale 1.0 <-> 1.05 lent, sans flash de luminosité.
class _CriticalPulse extends StatefulWidget {
  final Color color;
  final Widget child;
  const _CriticalPulse({required this.color, required this.child});

  @override
  State<_CriticalPulse> createState() => _CriticalPulseState();
}

class _CriticalPulseState extends State<_CriticalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      key: const Key('brain-timer-pulse'),
      scale: Tween(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
