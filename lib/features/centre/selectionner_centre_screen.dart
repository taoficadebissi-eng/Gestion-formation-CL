import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/centre_provider.dart';

class SelectionnerCentreScreen extends ConsumerWidget {
  const SelectionnerCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centresAsync = ref.watch(centresDuAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vos centres',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selectionnez le centre que vous souhaitez gerer',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: centresAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(child: Text('Erreur de chargement')),
                  data: (centres) {
                    if (centres.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.go('/centre/creer');
                      });
                      return const SizedBox();
                    }
                    return ListView.builder(
                      itemCount: centres.length,
                      itemBuilder: (context, index) {
                        final centre = centres[index];
                        return GestureDetector(
                          onTap: () {
                            ref.read(centreActifProvider.notifier).state = centre;
                            context.go('/admin/dashboard');
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.business_rounded, color: AppColors.primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        centre.nom,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${centre.ville}, ${centre.pays}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: AppColors.textSecondary, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Creer un nouveau centre',
                icon: Icons.add_business_rounded,
                outlined: true,
                onPressed: () => context.go('/centre/creer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
