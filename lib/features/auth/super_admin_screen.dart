import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/supabase/supabase_config.dart';
import '../../widgets/blurred_toast.dart';

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  final SupabaseClient _db = SupabaseConfig.client;
  bool _isLoading = false;

  String _genererCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(8);
    final random = (DateTime.now().microsecond % 9000 + 1000).toString();
    return 'INV-$timestamp-$random';
  }

  Future<void> _creerCode() async {
    setState(() => _isLoading = true);
    try {
      final code = _genererCode();
      await _db.from('invitations').insert({
        'token': code,
        'utilise': false,
        'date_creation': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        BlurredToast.show(
          context,
          'Code cree : $code',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _supprimerCode(String id) async {
    try {
      await _db.from('invitations').delete().eq('id', id);
      if (mounted) {
        BlurredToast.show(
          context,
          'Code supprime',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
  }

  void _copierCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    BlurredToast.show(
      context,
      'Code copie : $code',
      icon: Icons.copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Super Admin'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '/login',
          ), // Retour au login ou à l'accueil selon ta préférence
        ),
      ),
      body: Column(
        children: [
          // --- SECTION 1 : GESTION DES INVITATIONS (EXISTANT) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.red.shade50,
            child: Column(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gestion des codes d invitation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _creerCode,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _isLoading ? 'Creation...' : 'Generer un nouveau code',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- SECTION 2 : GESTION DES COURS GRATUITS (NOUVEAU) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors
                .blue
                .shade50, // Couleur différente pour distinguer les sections
            child: Column(
              children: [
                const Icon(Icons.school_rounded, size: 48, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  'Cours Gratuits Publics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ajouter ou modifier les cours visibles sur la page d accueil',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.go('/admin/gestion-cours'),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Ajouter un cours'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/liste-cours'),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Voir la liste des cours'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- LISTE DES CODES D INVITATION (EXISTANT) ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _db
                  .from('invitations')
                  .stream(primaryKey: ['id'])
                  .order('date_creation', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur : ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!;

                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun code d invitation'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    final id = data['id'] as String;
                    final token = data['token'] as String;
                    final utilise = data['utilise'] as bool;
                    final dateCreation = DateTime.parse(
                      data['date_creation'] as String,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          utilise
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: utilise ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          token,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '${utilise ? "Utilise" : "Disponible"} - ${dateCreation.day}/${dateCreation.month}/${dateCreation.year}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!utilise)
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  color: AppColors.primary,
                                ),
                                onPressed: () => _copierCode(token),
                                tooltip: 'Copier',
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppColors.error,
                              ),
                              onPressed: () => _supprimerCode(id),
                              tooltip: 'Supprimer',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
