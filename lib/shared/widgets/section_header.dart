// En-tête de section : titre fort + sous-titre optionnel + action.
// Hiérarchie typographique unique pour tous les écrans.
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: textTheme.titleLarge),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: BrainSpacing.xs),
                    child: Text(subtitle!, style: textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: BrainSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
