import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/firebase/firestore_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../models/invitation_model.dart';
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
      // Tout l'écran défile (en-tête + liste) : sur un téléphone, la liste des
      // codes reste atteignable même quand l'en-tête occupe la hauteur.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invitations.snapshots(),
        builder: (context, snapshot) {
          final List<Widget> contenu;
          if (snapshot.hasError) {
            contenu = [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur : ${snapshot.error}'),
              ),
            ];
          } else if (!snapshot.hasData) {
            contenu = const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ];
          } else {
            final codes =
                snapshot.data!.docs.map(InvitationModel.depuis).toList()
                  ..sort((a, b) {
                    if (a.date == null && b.date == null) return 0;
                    if (a.date == null) return 1;
                    if (b.date == null) return -1;
                    return b.date!.compareTo(a.date!);
                  });
            contenu = codes.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun code d\'invitation')),
                    ),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Text(
                        '${codes.length} code${codes.length > 1 ? "s" : ""} - '
                        '${codes.where((c) => c.disponible).length} disponible'
                        '${codes.where((c) => c.disponible).length > 1 ? "s" : ""}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    ...codes.map(_carteCode),
                  ];
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [_enTete(), ...contenu],
          );
        },
      ),
    );
  }

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Colors.red.shade50,
      child: Column(
        children: [
          const Icon(Icons.admin_panel_settings, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text(
            'Gestion des codes d\'invitation',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _CarteVisiteurs(),
          const SizedBox(height: 16),
          const _BoutonPropositions(),
          const SizedBox(height: 12),
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
            label: Text(_isLoading ? 'Creation...' : 'Generer un nouveau code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteCode(InvitationModel code) {
    final date = code.date;
    final String etat;
    if (!code.valide) {
      etat = 'Ancien code, inutilisable';
    } else {
      etat = code.utilise ? 'Utilise' : 'Disponible';
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ListTile(
        leading: Icon(
          code.utilise
              ? Icons.check_circle
              : (code.valide
                    ? Icons.radio_button_unchecked
                    : Icons.history_toggle_off),
          color: code.utilise
              ? Colors.green
              : (code.valide ? Colors.orange : Colors.grey),
        ),
        title: Text(
          code.token,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          date == null
              ? etat
              : '$etat - ${date.day}/${date.month}/${date.year}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code.disponible)
              IconButton(
                icon: const Icon(Icons.copy, color: AppColors.primary),
                onPressed: () => _copierCode(code.token),
                tooltip: 'Copier',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () => _supprimerCode(code.id),
              tooltip: 'Supprimer',
            ),
          ],
        ),
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

/// Accès aux cours proposés par la veille automatique, avec leur nombre.
class _BoutonPropositions extends ConsumerWidget {
  const _BoutonPropositions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(propositionsProvider).value?.length ?? 0;
    return ElevatedButton.icon(
      onPressed: () => context.go('/super-admin/propositions'),
      icon: const Icon(Icons.auto_awesome),
      label: Text(
        nombre == 0
            ? 'Propositions de cours'
            : 'Propositions de cours ($nombre a valider)',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: nombre == 0
            ? Colors.grey.shade600
            : Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
    );
  }
}
