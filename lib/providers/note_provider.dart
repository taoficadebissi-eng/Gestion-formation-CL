import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

final noteServiceProvider = Provider<NoteService>((ref) => NoteService());

final notesFormationProvider = StreamProvider.family<List<NoteModel>, String>((
  ref,
  formationId,
) {
  return ref.watch(noteServiceProvider).ecouterNotes(formationId);
});
