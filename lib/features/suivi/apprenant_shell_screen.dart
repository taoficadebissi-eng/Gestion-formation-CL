import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../providers/message_admin_provider.dart';
import '../messagerie/apprenant_messages_tab.dart';
import 'espace_apprenant_screen.dart';
import 'paiements_apprenant_screen.dart';

/// Shell de navigation par onglets pour l'apprenant (Phase 1 de la
/// refonte) : Mes formations / Paiements / Messages.
class ApprenantShellScreen extends ConsumerStatefulWidget {
  const ApprenantShellScreen({super.key});

  @override
  ConsumerState<ApprenantShellScreen> createState() => _ApprenantShellScreenState();
}

class _ApprenantShellScreenState extends ConsumerState<ApprenantShellScreen> {
  int _index = 0;

  static const _tabs = [
    EspaceApprenantScreen(),
    PaiementsApprenantScreen(),
    ApprenantMessagesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final messagesNonLus = ref.watch(apprenantMessagesNonLusProvider).value ?? false;

    final items = [
      const AppBottomNavItem(
        icone: Icons.book_outlined,
        iconeSelectionne: Icons.book_rounded,
        label: 'Mes formations',
      ),
      const AppBottomNavItem(
        icone: Icons.payments_outlined,
        iconeSelectionne: Icons.payments_rounded,
        label: 'Paiements',
      ),
      AppBottomNavItem(
        icone: Icons.chat_bubble_outline_rounded,
        iconeSelectionne: Icons.chat_bubble_rounded,
        label: 'Messages',
        avecBadge: messagesNonLus,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        items: items,
      ),
    );
  }
}
