import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppBottomNavItem {
  final IconData icone;
  final IconData iconeSelectionne;
  final String label;
  /// true pour afficher un point rouge sur l'icône (badge "non lu", Phase 6).
  final bool avecBadge;

  const AppBottomNavItem({
    required this.icone,
    required this.iconeSelectionne,
    required this.label,
    this.avecBadge = false,
  });
}

/// Bottom navigation bar réutilisable pour les 3 rôles (admin, formateur,
/// apprenant) : la liste d'onglets varie selon le rôle connecté, le widget
/// lui-même reste identique.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavItem> items;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  Widget _iconeAvecBadge(IconData icone, Color? couleur, bool avecBadge) {
    final child = couleur != null ? Icon(icone, color: couleur) : Icon(icone);
    if (!avecBadge) return child;
    return Badge(
      backgroundColor: AppColors.error,
      smallSize: 8,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: _iconeAvecBadge(item.icone, null, item.avecBadge),
              selectedIcon: _iconeAvecBadge(item.iconeSelectionne, AppColors.primary, item.avecBadge),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}
