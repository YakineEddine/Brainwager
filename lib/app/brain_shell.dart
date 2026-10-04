// Coquille persistante (light-shell) : StatefulNavigationShell + barre
// Material 3 claire. L'état des onglets est préservé par indexedStack.
// RTL-safe (NavigationBar natif), labels localisés, état sélectionné
// évident (indicateur + icône pleine).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

class BrainDestination {
  final String location;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const BrainDestination({
    required this.location,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Destinations de la barre persistante (ordre = index des branches).
List<BrainDestination> brainDestinations(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    BrainDestination(
      location: '/home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: l10n.navHome,
    ),
    BrainDestination(
      location: '/packs',
      icon: Icons.style_outlined,
      selectedIcon: Icons.style,
      label: l10n.navPacks,
    ),
    BrainDestination(
      location: '/shop',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      label: l10n.navShop,
    ),
    BrainDestination(
      location: '/profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: l10n.navProfile,
    ),
  ];
}

class BrainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const BrainShell({super.key, required this.shell});

  void _goBranch(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = brainDestinations(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: Icon(destinations[i].icon),
              selectedIcon: Icon(destinations[i].selectedIcon),
              label: destinations[i].label,
            ),
        ],
      ),
    );
  }
}
