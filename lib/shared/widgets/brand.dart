// Marque Brainwager : point d'intégration unique du logo.
// Artwork final approuvé et activé (assets/branding/, déclaré pubspec).
// Le repli wordmark + errorBuilder restent actifs si un chargement échoue.
// Variantes : full / compact / markOnly. Tailles configurables, RTL-safe.
import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum BrainBrandVariant { full, compact, markOnly }

/// Chemins finaux (assets/branding/, artwork approuvé, déclaré pubspec).
/// Fonction publique pure pour testabilité ; le widget l'utilise tel quel.
/// Le repli wordmark + errorBuilder restent actifs si un chargement échoue.
String? brainBrandAsset(BrainBrandVariant variant) {
  switch (variant) {
    case BrainBrandVariant.full:
      return 'assets/branding/brainwager_logo.png';
    case BrainBrandVariant.compact:
      return 'assets/branding/brainwager_logo_compact.png';
    case BrainBrandVariant.markOnly:
      return 'assets/branding/brainwager_mark.png';
  }
}

String? _brandAssetFor(BrainBrandVariant variant) => brainBrandAsset(variant);

class BrainBrand extends StatelessWidget {
  final BrainBrandVariant variant;
  final double height;
  final bool centered;
  const BrainBrand({
    super.key,
    this.variant = BrainBrandVariant.full,
    this.height = 72,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _brandAssetFor(variant);
    final Widget content;
    if (asset != null) {
      content = Image.asset(
        asset,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _Wordmark(variant: variant, height: height),
      );
    } else {
      content = _Wordmark(variant: variant, height: height);
    }
    if (!centered) return content;
    return Center(child: content);
  }
}

/// Wordmark temporaire : typographie forte + point or (pas de logo final).
class _Wordmark extends StatelessWidget {
  final BrainBrandVariant variant;
  final double height;
  const _Wordmark({required this.variant, required this.height});

  @override
  Widget build(BuildContext context) {
    final scale = (height / 72).clamp(0.5, 2.0);
    final title = Text(
      'BRAINWAGER',
      style: TextStyle(
        fontSize: 30 * scale,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: BrainColors.textPrimary,
      ),
    );
    switch (variant) {
      case BrainBrandVariant.full:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        BrainColors.electricViolet,
                        BrainColors.electricVioletDeep,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.w900,
                      color: BrainColors.gold,
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
                Flexible(child: title),
              ],
            ),
          ],
        );
      case BrainBrandVariant.compact:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34 * scale,
              height: 34 * scale,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    BrainColors.electricViolet,
                    BrainColors.electricVioletDeep,
                  ],
                ),
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              alignment: Alignment.center,
              child: Text(
                'B',
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w900,
                  color: BrainColors.gold,
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            Flexible(child: title),
          ],
        );
      case BrainBrandVariant.markOnly:
        return Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                BrainColors.electricViolet,
                BrainColors.electricVioletDeep,
              ],
            ),
            borderRadius: BorderRadius.circular(height * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'B',
            style: TextStyle(
              fontSize: height * 0.55,
              fontWeight: FontWeight.w900,
              color: BrainColors.gold,
            ),
          ),
        );
    }
  }
}
