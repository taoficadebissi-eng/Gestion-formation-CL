import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/inscription_model.dart';
import '../../models/user_model.dart';
import '../../providers/formation_provider.dart';
import '../../providers/inscription_provider.dart'; // ✅ Garder cet import pour les StreamProviders
import '../../providers/user_provider.dart';
import '../../widgets/blurred_toast.dart';
import '../messagerie/group_chat_screen.dart';
import 'widgets/notes_section.dart';

class DetailFormationScreen extends ConsumerWidget {
  final String formationId;

  const DetailFormationScreen({super.key, required this.formationId});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationsAsync = ref.watch(formationsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    // ✅ CORRECTION NOM DU PROVIDER
    final inscriptionsAsync = ref.watch(
      inscriptionsFormationProvider(formationId),
    );

    return formationsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Erreur : ${e.toString()}'))),
      data: (formations) {
        final formation = formations
            .where((f) => f.id == formationId)
            .firstOrNull;
        if (formation == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Formation introuvable')),
            body: const Center(child: Text('Cette formation n existe plus')),
          );
        }

        return userProfileAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Erreur profil : ${e.toString()}')),
          ),
          data: (userProfile) {
            if (userProfile == null) {
              return const Scaffold(
                body: Center(child: Text('Profil utilisateur introuvable')),
              );
            }

            final peutModifier =
                userProfile.role == UserRole.admin ||
                userProfile.role == UserRole.formateur;
            final estApprenant = userProfile.role == UserRole.apprenant;
            final inscriptions = inscriptionsAsync.value ?? [];
            final dejaInscrit = inscriptions.any(
              (i) => i.apprenantId == userProfile.id,
            );
            final monInscription = dejaInscrit
                ? inscriptions.firstWhere(
                    (i) => i.apprenantId == userProfile.id,
                  )
                : null;

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Details de la formation'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (userProfile.role == UserRole.apprenant) {
                      context.go('/espace-apprenant');
                    } else if (userProfile.role == UserRole.formateur) {
                      context.go('/dashboard-formateur');
                    } else {
                      context.go('/formations');
                    }
                  },
                ),
                actions: [
                  if (peutModifier)
                    IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      color: Colors.white,
                      onPressed: () async {
                        final confirmer = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Supprimer la formation'),
                            content: const Text(
                              'Etes-vous sur de vouloir supprimer cette formation ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirmer == true && context.mounted) {
                          try {
                            await ref
                                .read(formationNotifierProvider.notifier)
                                .supprimer(formationId);
                            if (context.mounted) {
                              userProfile.role == UserRole.apprenant
                                  ? context.go('/espace-apprenant')
                                  : userProfile.role == UserRole.formateur
                                  ? context.go('/dashboard-formateur')
                                  : context.go('/formations');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              BlurredToast.show(
                                context,
                                'Erreur lors de la suppression : $e',
                                icon: Icons.error_outline,
                              );
                            }
                          }
                        }
                      },
                    ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        image: (formation.imageUrl != null &&
                                formation.imageUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(formation.imageUrl!),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.35),
                                  BlendMode.darken,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.book_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            formation.titre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formation.niveau,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (dejaInscrit) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Inscrit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoCard(
                      titre: 'Description',
                      contenu: formation.description,
                      icone: Icons.description_outlined,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      titre: 'Formateur',
                      contenu: formation.formateurNom.isEmpty
                          ? 'Non defini'
                          : formation.formateurNom,
                      icone: Icons.person_outlined,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      titre: 'Nombre de sessions',
                      contenu: '${formation.nombreSessions} sessions',
                      icone: Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      titre: 'Date de debut',
                      contenu: _formatDate(formation.dateDebut),
                      icone: Icons.event_rounded,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      titre: 'Date de fin',
                      contenu: _formatDate(formation.dateFin),
                      icone: Icons.event_available_rounded,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      titre: 'Date de creation',
                      contenu: _formatDate(formation.dateCreation),
                      icone: Icons.access_time_rounded,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: peutModifier
                          ? () =>
                                context.go('/formations/$formationId/inscrits')
                          : null,
                      child: _InfoCard(
                        titre: peutModifier
                            ? 'Apprenants inscrits (appuyer pour voir)'
                            : 'Apprenants inscrits',
                        contenu: '${inscriptions.length} apprenant(s)',
                        icone: Icons.people_rounded,
                      ),
                    ),
                    if (formation.prerequisId != null &&
                        formation.prerequisId!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final prerequis = formations
                              .where((f) => f.id == formation.prerequisId)
                              .firstOrNull;
                          return GestureDetector(
                            onTap: prerequis != null
                                ? () => context.go('/formations/${prerequis.id}')
                                : null,
                            child: _InfoCard(
                              titre: 'Formation prerequise',
                              contenu: prerequis?.titre ?? 'Formation introuvable',
                              icone: Icons.link_rounded,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    NotesSection(
                      formationId: formationId,
                      userId: userProfile.id,
                      peutAjouter: userProfile.role == UserRole.formateur,
                      estBloque: monInscription?.statutPaiement ==
                          StatutPaiement.bloque,
                    ),
                    if (peutModifier || dejaInscrit) ...[
                      const SizedBox(height: 16),
                      CustomButton(
                        label: 'Discussion du groupe',
                        icon: Icons.forum_rounded,
                        outlined: true,
                        color: AppColors.secondary,
                        onPressed: (estApprenant &&
                                monInscription?.statutPaiement ==
                                    StatutPaiement.bloque)
                            ? null
                            : () {
                                final nomParUid = <String, String>{
                                  formation.formateurId: formation.formateurNom,
                                  for (final i in inscriptions)
                                    i.apprenantId: i.apprenantNom,
                                };
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GroupChatScreen(
                                      formationId: formationId,
                                      formationTitre: formation.titre,
                                      userId: userProfile.id,
                                      nomParUid: nomParUid,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                    const SizedBox(height: 32),
                    CustomButton(
                      label: 'Voir les sessions',
                      icon: Icons.calendar_month_rounded,
                      outlined: true,
                      onPressed: () =>
                          context.go('/formations/$formationId/sessions'),
                    ),
                    if (estApprenant) ...[
                      const SizedBox(height: 12),
                      dejaInscrit
                          ? CustomButton(
                              label: 'Se desinscrire',
                              icon: Icons.remove_circle_outline_rounded,
                              color: AppColors.error,
                              onPressed: () async {
                                final confirmer = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Se desinscrire'),
                                    content: const Text(
                                      'Etes-vous sur de vouloir vous desinscrire ?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text(
                                          'Annuler',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Se desinscrire'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmer == true && context.mounted) {
                                  await ref
                                      .read(
                                        inscriptionNotifierProvider.notifier,
                                      )
                                      .annuler(monInscription!.id);
                                  // ✅ CORRECTION INVALIDATION
                                  ref.invalidate(
                                    inscriptionsFormationProvider(formationId),
                                  );
                                  ref.invalidate(
                                    inscriptionsApprenantProvider(
                                      userProfile.id,
                                    ),
                                  );
                                  if (context.mounted) {
                                    BlurredToast.show(
                                      context,
                                      'Desinscription effectuee',
                                      icon: Icons.info_outline,
                                      duration: const Duration(seconds: 2),
                                    );
                                  }
                                }
                              },
                            )
                          : CustomButton(
                              label: 'S inscrire a cette formation',
                              icon: Icons.person_add_rounded,
                              onPressed: () async {
                                final dejaInscritCheck = await ref
                                    .read(inscriptionServiceProvider)
                                    .estInscrit(userProfile.id, formationId);
                                if (dejaInscritCheck) {
                                  if (context.mounted) {
                                    BlurredToast.show(
                                      context,
                                      'Vous etes deja inscrit a cette formation',
                                      icon: Icons.error_outline,
                                      duration: const Duration(seconds: 2),
                                    );
                                  }
                                  return;
                                }

                                // Avertissement non bloquant si le prerequis
                                // n'est pas valide (Phase 4) : "valide" =
                                // l'apprenant a une inscription existante
                                // pour la formation prerequise.
                                if (formation.prerequisId != null &&
                                    formation.prerequisId!.isNotEmpty) {
                                  final prerequisValide = await ref
                                      .read(inscriptionServiceProvider)
                                      .estInscrit(
                                        userProfile.id,
                                        formation.prerequisId!,
                                      );
                                  if (!prerequisValide && context.mounted) {
                                    final prerequisFormation = formations
                                        .where(
                                          (f) => f.id == formation.prerequisId,
                                        )
                                        .firstOrNull;
                                    final continuer = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: const Text('Prerequis non valide'),
                                        content: Text(
                                          'Cette formation recommande d\'avoir suivi '
                                          '"${prerequisFormation?.titre ?? 'une formation prerequise'}" '
                                          'au prealable. Vous pouvez tout de meme vous inscrire.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Annuler'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'S\'inscrire quand meme',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (continuer != true) return;
                                  }
                                }

                                final inscription = InscriptionModel(
                                  id: '',
                                  apprenantId: userProfile.id,
                                  apprenantNom:
                                      '${userProfile.prenom} ${userProfile.nom}',
                                  formationId: formationId,
                                  centreId: userProfile.centreId,
                                  dateInscription: DateTime.now(),
                                  statut: StatutInscription.confirmee,
                                );
                                try {
                                  await ref
                                      .read(
                                        inscriptionNotifierProvider.notifier,
                                      )
                                      .inscrire(inscription);
                                  // ✅ CORRECTION INVALIDATION
                                  ref.invalidate(
                                    inscriptionsFormationProvider(formationId),
                                  );
                                  ref.invalidate(
                                    inscriptionsApprenantProvider(
                                      userProfile.id,
                                    ),
                                  );
                                  if (context.mounted) {
                                    BlurredToast.show(
                                      context,
                                      'Inscription effectuee avec succes !',
                                      icon: Icons.check_circle_outline,
                                      duration: const Duration(seconds: 2),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    BlurredToast.show(
                                      context,
                                      e.toString().contains('deja inscrit')
                                          ? 'Vous etes deja inscrit a cette formation'
                                          : 'Erreur lors de l inscription',
                                      icon: Icons.error_outline,
                                      duration: const Duration(seconds: 2),
                                    );
                                  }
                                }
                              },
                            ),
                    ],
                    if (peutModifier) ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        label: 'Modifier la formation',
                        icon: Icons.edit_rounded,
                        onPressed: () =>
                            context.go('/formations/$formationId/modifier'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String titre;
  final String contenu;
  final IconData icone;
  const _InfoCard({
    required this.titre,
    required this.contenu,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contenu,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
