import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

class GestionUsersScreen extends ConsumerWidget {
  /// true quand cet écran est l'onglet "Utilisateurs" d'un shell à bottom
  /// navigation (Phase 1) : pas de flèche retour dans ce cas, l'onglet
  /// "Accueil" du même shell en tient déjà lieu.
  final bool embeddedInShell;

  const GestionUsersScreen({super.key, this.embeddedInShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(utilisateursDuCentreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: embeddedInShell
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/dashboard'),
              ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: ${e.toString()}')),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun utilisateur',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cr ez votre premier utilisateur',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/users/creer'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Ajouter un utilisateur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.role == UserRole.apprenant
                        ? Colors.blue.shade100
                        : Colors.orange.shade100,
                    child: Text('${user.prenom[0]}${user.nom[0]}'),
                  ),
                  title: Text('${user.prenom} ${user.nom}'),
                  subtitle: Text(user.email),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.role == UserRole.apprenant
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role == UserRole.apprenant
                          ? 'Apprenant'
                          : 'Formateur',
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/admin/users/creer'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
