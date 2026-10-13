import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../providers/message_provider.dart';
import '../messagerie/formateur_messages_tab.dart';
import 'accueil_formateur_screen.dart';
import 'dashboard_formateur_screen.dart';

/// Shell de navigation par onglets pour le formateur (Phase 1 de la
/// refonte) : Accueil / Mes formations / Messages.
class FormateurShellScreen extends ConsumerStatefulWidget {
  const FormateurShellScreen({super.key});

  @override
  ConsumerState<FormateurShellScreen> createState() =>
      _FormateurShellScreenState();
}

class _FormateurShellScreenState extends ConsumerState<FormateurShellScreen> {
  int _index = 0;

  static const _tabs = [
    AccueilFormateurScreen(),
    DashboardFormateurScreen(),
    FormateurMessagesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final messagesNonLus =
        ref.watch(formateurMessagesNonLusProvider).value ?? false;

    final items = [
      const AppBottomNavItem(
        icone: Icons.home_outlined,
        iconeSelectionne: Icons.home_rounded,
        label: 'Accueil',
      ),
      const AppBottomNavItem(
        icone: Icons.book_outlined,
        iconeSelectionne: Icons.book_rounded,
        label: 'Mes formations',
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
