import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/conversation_admin_model.dart';
import '../../providers/message_admin_provider.dart';
import '../../services/lecture_tracker.dart';
import '../../widgets/blurred_toast.dart';

String _formatHeure(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// Conversation 1-a-1 admin <-> apprenant (Phase 6).
class AdminChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String titre;
  final String userId;

  const AdminChatScreen({
    super.key,
    required this.conversationId,
    required this.titre,
    required this.userId,
  });

  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    LectureTracker.marquerLu('conversation_${widget.conversationId}');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) return;
    setState(() => _envoiEnCours = true);
    try {
      await ref.read(messageAdminServiceProvider).envoyerMessage(
            MessageAdminModel(
              id: '',
              conversationId: widget.conversationId,
              auteurId: widget.userId,
              texte: texte,
              dateEnvoi: DateTime.now(),
            ),
          );
      await LectureTracker.marquerLu('conversation_${widget.conversationId}');
      _controller.clear();
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur lors de l\'envoi : $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesConversationProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.titre, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun message pour le moment.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final estMoi = message.auteurId == widget.userId;
                    return Align(
                      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: estMoi ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: estMoi ? null : Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.texte,
                              style: TextStyle(color: estMoi ? Colors.white : AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatHeure(message.dateEnvoi),
                              style: TextStyle(fontSize: 10, color: estMoi ? Colors.white70 : AppColors.textSecondary),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ecrire un message...',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _envoiEnCours
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: _envoyer,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
