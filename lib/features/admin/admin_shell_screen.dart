import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../providers/message_admin_provider.dart';
import '../formations/catalogue_screen.dart';
import '../messagerie/admin_conversations_screen.dart';
import 'accueil_admin_tab.dart';
import 'gestion_users_screen.dart';

/// Shell de navigation par onglets pour l'admin (Phase 1 de la refonte) :
/// Accueil / Formations / Utilisateurs / Messages.
class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _index = 0;

  static const _tabs = [
    AccueilAdminTab(),
    CatalogueScreen(embeddedInShell: true),
    GestionUsersScreen(embeddedInShell: true),
    AdminConversationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final messagesNonLus = ref.watch(adminMessagesNonLusProvider).value ?? false;

    final items = [
      const AppBottomNavItem(icone: Icons.home_outlined, iconeSelectionne: Icons.home_rounded, label: 'Accueil'),
      const AppBottomNavItem(icone: Icons.book_outlined, iconeSelectionne: Icons.book_rounded, label: 'Formations'),
      const AppBottomNavItem(
        icone: Icons.people_outline_rounded,
        iconeSelectionne: Icons.people_rounded,
        label: 'Utilisateurs',
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
