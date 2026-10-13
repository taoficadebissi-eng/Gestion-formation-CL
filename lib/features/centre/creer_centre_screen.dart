import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/centre_model.dart';
import '../../providers/centre_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/blurred_toast.dart';

class CreerCentreScreen extends ConsumerStatefulWidget {
  const CreerCentreScreen({super.key});

  @override
  ConsumerState<CreerCentreScreen> createState() => _CreerCentreScreenState();
}

class _CreerCentreScreenState extends ConsumerState<CreerCentreScreen> {
  final _nomController = TextEditingController();
  final _villeController = TextEditingController();
  final _paysController = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _nomController.dispose();
    _villeController.dispose();
    _paysController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    setState(() => _erreur = null);

    if (_nomController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom du centre est obligatoire');
      return;
    }
    if (_villeController.text.trim().isEmpty) {
      setState(() => _erreur = 'La ville est obligatoire');
      return;
    }
    if (_paysController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le pays est obligatoire');
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      setState(() => _erreur = 'Profil utilisateur introuvable');
      return;
    }

    final centre = CentreModel(
      id: '',
      nom: _nomController.text.trim(),
      ville: _villeController.text.trim(),
      pays: _paysController.text.trim(),
      adminId: userProfile.id,
      dateCreation: DateTime.now(),
    );

    try {
      await ref.read(centreNotifierProvider.notifier).creer(centre);
      if (mounted) {
        BlurredToast.show(
          context,
          'Centre cree avec succes !',
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        context.go('/admin/dashboard');
      }
    } catch (e) {
      setState(() => _erreur = 'Erreur lors de la creation du centre');
    }
  }

  @override
  Widget build(BuildContext context) {
    final centreState = ref.watch(centreNotifierProvider);
    final isLoading = centreState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Creer un centre'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
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
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              TextField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom du centre',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _villeController,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paysController,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  prefixIcon: Icon(Icons.flag_rounded),
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Creer le centre',
                icon: Icons.add_business_rounded,
                isLoading: isLoading,
                onPressed: _creer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
