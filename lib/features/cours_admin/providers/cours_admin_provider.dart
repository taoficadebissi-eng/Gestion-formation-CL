import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cours_gratuit_model.dart';
import '../services/cours_admin_service.dart';

final coursAdminServiceProvider = Provider<CoursAdminService>(
  (ref) => CoursAdminService(),
);

final coursAdminProvider = StreamProvider<List<CoursGratuit>>(
  (ref) => ref.watch(coursAdminServiceProvider).ecouterTous(),
);

final visiteursProvider = StreamProvider<int>(
  (ref) => ref.watch(coursAdminServiceProvider).ecouterVisiteurs(),
);
