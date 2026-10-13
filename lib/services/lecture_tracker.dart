import 'package:shared_preferences/shared_preferences.dart';

/// Suivi (local, par appareil) de la dernière lecture d'une conversation ou
/// d'un chat de groupe, pour le badge "messages non lus" de l'onglet
/// Messages (Phase 6 : "simple compteur, pas besoin de notifications push").
/// Pas de champ dédié en base : un horodatage par appareil dans
/// shared_preferences suffit pour ce besoin et évite une migration de plus.
class LectureTracker {
  static const _prefixe = 'derniere_lecture_';

  static Future<void> marquerLu(String cle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefixe$cle',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> estNonLu(String cle, DateTime? dernierMessageDate) async {
    if (dernierMessageDate == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final derniereLectureStr = prefs.getString('$_prefixe$cle');
    if (derniereLectureStr == null) return true;
    final derniereLecture = DateTime.tryParse(derniereLectureStr);
    if (derniereLecture == null) return true;
    return dernierMessageDate.isAfter(derniereLecture);
  }
}
