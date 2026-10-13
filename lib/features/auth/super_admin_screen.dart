import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/firebase/firestore_helpers.dart';
import '../../providers/auth_provider.dart';
import '../cours_admin/providers/cours_admin_provider.dart';
import '../../widgets/blurred_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Espace super-admin : génération et suivi des codes d'invitation qui
/// permettent à un futur admin de créer son compte. Accessible uniquement
/// avec le compte Firebase du super-admin (e-mail vérifié), côté routeur et
/// côté règles Firestore.
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  final _invitations = firestore.collection('invitations');
  bool _isLoading = false;

  /// Code à 20 caractères tirés d'un générateur cryptographique : impossible
  /// à deviner, contrairement à un code construit à partir de l'heure.
  String _genererCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final partie = List.generate(
      20,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'INV-${partie.substring(0, 5)}-${partie.substring(5, 10)}-'
        '${partie.substring(10, 15)}-${partie.substring(15)}';
  }

  Future<void> _creerCode() async {
    setState(() => _isLoading = true);
    try {
      final code = _genererCode();
      await _invitations.doc(code).set({
        'token': code,
        'utilise': false,
        'admin_id': null,
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
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _supprimerCode(String code) async {
    try {
      await _invitations.doc(code).delete();
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
    BlurredToast.show(context, 'Code copie : $code', icon: Icons.copy_rounded);
  }

  Future<void> _deconnecter() async {
    await ref.read(authNotifierProvider.notifier).deconnexion();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Super Admin'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconnexion',
            onPressed: _deconnecter,
          ),
        ],
      ),
      body: Column(
        children: [
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
                  'Gestion des codes d\'invitation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const _CarteVisiteurs(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/super-admin/cours'),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Voir les cours publics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 12),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _invitations.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur : ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.toJsonListe()
                  ..sort(
                    (a, b) => (b['date_creation'] as String).compareTo(
                      a['date_creation'] as String,
                    ),
                  );

                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun code d\'invitation'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
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
                          '${utilise ? "Utilise" : "Disponible"} - '
                          '${dateCreation.day}/${dateCreation.month}/${dateCreation.year}',
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
                              onPressed: () => _supprimerCode(token),
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

/// Nombre total de visiteurs de la vitrine publique CoursLibre.
class _CarteVisiteurs extends ConsumerWidget {
  const _CarteVisiteurs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(visiteursProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total.when(
                  data: (n) => '$n',
                  loading: () => '...',
                  error: (_, _) => '-',
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'visiteurs sur CoursLibre',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
