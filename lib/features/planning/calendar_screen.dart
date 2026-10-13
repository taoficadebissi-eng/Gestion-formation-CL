import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/formation_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/user_provider.dart';
import '../suivi/feuille_presence_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _moisAffiche;
  late DateTime _jourSelectionne;

  static const _joursSemaine = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
  static const _mois = [
    'Janvier',
    'Fevrier',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'Septembre',
    'Octobre',
    'Novembre',
    'Decembre',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _moisAffiche = DateTime(now.year, now.month);
    _jourSelectionne = DateTime(now.year, now.month, now.day);
  }

  void _changerMois(int delta) {
    setState(() {
      _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsCentreProvider);
    final formations = ref.watch(formationsProvider).value ?? [];
    final userProfile = ref.watch(userProfileProvider).value;
    final peutGerer =
        userProfile?.role == UserRole.admin ||
        userProfile?.role == UserRole.formateur;

    String titreFormation(String formationId) {
      final f = formations.where((f) => f.id == formationId).firstOrNull;
      return f?.titre ?? 'Formation';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendrier des sessions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (sessions) {
          final parJour = <DateTime, List<SessionModel>>{};
          for (final s in sessions) {
            final cle = DateTime(s.date.year, s.date.month, s.date.day);
            parJour.putIfAbsent(cle, () => []).add(s);
          }
          final sessionsDuJour =
              parJour[DateTime(
                _jourSelectionne.year,
                _jourSelectionne.month,
                _jourSelectionne.day,
              )] ??
              [];

          return Column(
            children: [
              _EnTeteMois(
                libelle:
                    '${_mois[_moisAffiche.month - 1]} ${_moisAffiche.year}',
                onPrecedent: () => _changerMois(-1),
                onSuivant: () => _changerMois(1),
                onAujourdhui: () {
                  final now = DateTime.now();
                  setState(() {
                    _moisAffiche = DateTime(now.year, now.month);
                    _jourSelectionne = DateTime(now.year, now.month, now.day);
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _joursSemaine
                      .map(
                        (j) => Expanded(
                          child: Center(
                            child: Text(
                              j,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              _GrilleMois(
                moisAffiche: _moisAffiche,
                jourSelectionne: _jourSelectionne,
                sessionsParJour: parJour,
                onJourTap: (jour) => setState(() => _jourSelectionne = jour),
              ),
              const Divider(height: 1),
              Expanded(
                child: sessionsDuJour.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune session ce jour-la',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessionsDuJour.length,
                        itemBuilder: (context, index) {
                          final session = sessionsDuJour[index];
                          return GestureDetector(
                            onTap: () {
                              if (peutGerer) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FeuillePresenceScreen(session: session),
                                  ),
                                );
                              } else {
                                context.go(
                                  '/formations/${session.formationId}',
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: AppTheme.softCard(radius: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.event_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titreFormation(session.formationId),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${session.heureDebut} - ${session.heureFin}'
                                          '${session.salle.isNotEmpty ? ' • ${session.salle}' : ''}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnTeteMois extends StatelessWidget {
  final String libelle;
  final VoidCallback onPrecedent;
  final VoidCallback onSuivant;
  final VoidCallback onAujourdhui;

  const _EnTeteMois({
    required this.libelle,
    required this.onPrecedent,
    required this.onSuivant,
    required this.onAujourdhui,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
            onPressed: onPrecedent,
          ),
          Expanded(
            child: Text(
              libelle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primary,
            onPressed: onSuivant,
          ),
          TextButton(
            onPressed: onAujourdhui,
            child: const Text('Aujourd\'hui'),
          ),
        ],
      ),
    );
  }
}

class _GrilleMois extends StatelessWidget {
  final DateTime moisAffiche;
  final DateTime jourSelectionne;
  final Map<DateTime, List<SessionModel>> sessionsParJour;
  final ValueChanged<DateTime> onJourTap;

  const _GrilleMois({
    required this.moisAffiche,
    required this.jourSelectionne,
    required this.sessionsParJour,
    required this.onJourTap,
  });

  @override
  Widget build(BuildContext context) {
    final premierJourDuMois = DateTime(moisAffiche.year, moisAffiche.month, 1);
    final nombreJours = DateTime(
      moisAffiche.year,
      moisAffiche.month + 1,
      0,
    ).day;
    // weekday: Lundi=1 ... Dimanche=7. On veut décaler pour commencer la
    // grille un lundi.
    final decalage = premierJourDuMois.weekday - 1;
    final aujourdHui = DateTime.now();

    final cellules = <Widget>[];
    for (var i = 0; i < decalage; i++) {
      cellules.add(const SizedBox.shrink());
    }
    for (var jour = 1; jour <= nombreJours; jour++) {
      final date = DateTime(moisAffiche.year, moisAffiche.month, jour);
      final aDesSessions = sessionsParJour.containsKey(date);
      final estSelectionne =
          date.year == jourSelectionne.year &&
          date.month == jourSelectionne.month &&
          date.day == jourSelectionne.day;
      final estAujourdhui =
          date.year == aujourdHui.year &&
          date.month == aujourdHui.month &&
          date.day == aujourdHui.day;

      cellules.add(
        GestureDetector(
          onTap: () => onJourTap(date),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: estSelectionne ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: estAujourdhui && !estSelectionne
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$jour',
                  style: TextStyle(
                    color: estSelectionne
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: estAujourdhui || estSelectionne
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                if (aDesSessions)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: estSelectionne
                          ? Colors.white
                          : AppColors.secondary,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: cellules,
      ),
    );
  }
}
