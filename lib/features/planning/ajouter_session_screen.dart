import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/session_model.dart';
import '../../providers/session_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/blurred_toast.dart';

class AjouterSessionScreen extends ConsumerStatefulWidget {
  final String formationId;
  const AjouterSessionScreen({super.key, required this.formationId});

  @override
  ConsumerState<AjouterSessionScreen> createState() => _AjouterSessionScreenState();
}

class _AjouterSessionScreenState extends ConsumerState<AjouterSessionScreen> {
  final _titreController = TextEditingController();
  final _detailsController = TextEditingController();
  final _salleController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _heureDebut;
  TimeOfDay? _heureFin;
  bool _repetition = false;
  int _nombreRepetitions = 1;
  String _frequence = 'semaine';
  String? _erreur;

  @override
  void dispose() {
    _titreController.dispose();
    _detailsController.dispose();
    _salleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHeure(TimeOfDay heure) {
    return '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Date de la premiere session',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _choisirHeure(bool isDebut) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isDebut ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 10, minute: 0),
      helpText: isDebut ? 'Heure de debut' : 'Heure de fin',
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _heureDebut = picked;
        } else {
          _heureFin = picked;
        }
      });
    }
  }

  List<DateTime> _genererDates() {
    if (_date == null) return [];
    final dates = <DateTime>[_date!];
    if (!_repetition) return dates;
    final intervalJours = _frequence == 'semaine' ? 7 : 14;
    for (int i = 1; i < _nombreRepetitions; i++) {
      dates.add(_date!.add(Duration(days: intervalJours * i)));
    }
    return dates;
  }

  Future<void> _soumettre() async {
    setState(() => _erreur = null);
    if (_titreController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le titre est obligatoire');
      return;
    }
    if (_date == null) {
      setState(() => _erreur = 'La date est obligatoire');
      return;
    }
    if (_heureDebut == null) {
      setState(() => _erreur = 'L heure de debut est obligatoire');
      return;
    }
    if (_heureFin == null) {
      setState(() => _erreur = 'L heure de fin est obligatoire');
      return;
    }
    if (_salleController.text.trim().isEmpty) {
      setState(() => _erreur = 'La salle est obligatoire');
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) return;

    try {
      final dates = _genererDates();
      for (int i = 0; i < dates.length; i++) {
        final titre = dates.length > 1
            ? '${_titreController.text.trim()} - Seance ${i + 1}'
            : _titreController.text.trim();
        final session = SessionModel(
          id: '',
          formationId: widget.formationId,
          centreId: userProfile.centreId,
          titre: titre,
          details: _detailsController.text.trim(),
          date: dates[i],
          heureDebut: _formatHeure(_heureDebut!),
          heureFin: _formatHeure(_heureFin!),
          salle: _salleController.text.trim(),
          statut: StatutSession.planifiee,
        );
        await ref.read(sessionNotifierProvider.notifier).ajouter(session);
      }
      if (mounted) {
        BlurredToast.show(
          context,
          dates.length > 1
              ? '${dates.length} sessions ajoutees avec succes !'
              : 'Session ajoutee avec succes !',
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        context.go('/formations/${widget.formationId}/sessions');
      }
    } catch (e) {
      setState(() => _erreur = 'Erreur lors de l ajout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final isLoading = sessionState.isLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajouter une session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/formations/${widget.formationId}/sessions'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erreur != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(_erreur!, style: const TextStyle(color: AppColors.error)),
                ),
              TextField(
                controller: _titreController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la session',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Contenu de la session (optionnel)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _choisirDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        _date == null ? 'Date de la session' : _formatDate(_date!),
                        style: TextStyle(
                          color: _date == null ? AppColors.textSecondary : AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _choisirHeure(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _heureDebut == null ? 'Debut' : _formatHeure(_heureDebut!),
                              style: TextStyle(
                                color: _heureDebut == null ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _choisirHeure(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _heureFin == null ? 'Fin' : _formatHeure(_heureFin!),
                              style: TextStyle(
                                color: _heureFin == null ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _salleController,
                decoration: const InputDecoration(
                  labelText: 'Salle ou lien visio',
                  prefixIcon: Icon(Icons.room_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sessions repetitives',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Switch(
                          value: _repetition,
                          onChanged: (val) => setState(() => _repetition = val),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_repetition) ...[
                      const SizedBox(height: 16),
                      const Text('Frequence',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _frequence = 'semaine'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _frequence == 'semaine' ? AppColors.primary : AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _frequence == 'semaine' ? AppColors.primary : AppColors.border),
                                ),
                                child: Text('Chaque semaine',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _frequence == 'semaine' ? Colors.white : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _frequence = 'quinzaine'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _frequence == 'quinzaine' ? AppColors.primary : AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _frequence == 'quinzaine' ? AppColors.primary : AppColors.border),
                                ),
                                child: Text('Toutes les 2 sem.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _frequence == 'quinzaine' ? Colors.white : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Nombre de sessions : ',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                            onPressed: () => setState(() {
                              if (_nombreRepetitions > 2) _nombreRepetitions--;
                            }),
                          ),
                          Text('$_nombreRepetitions',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            onPressed: () => setState(() {
                              if (_nombreRepetitions < 52) _nombreRepetitions++;
                            }),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _date == null
                              ? 'Choisissez une date pour voir l apercu'
                              : '$_nombreRepetitions sessions seront creees, de ${_formatDate(_date!)} jusqu au ${_formatDate(_genererDates().last)}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: _repetition
                    ? 'Creer $_nombreRepetitions sessions'
                    : 'Ajouter la session',
                icon: Icons.add_circle_rounded,
                isLoading: isLoading,
                onPressed: _soumettre,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
