# Handoff — refonte Firebase et séparation de CoursLibre

## Fait
- Dépôt git initialisé (`main` = état avant refonte, branche `refonte-firebase`).
- Gestion Formation : retour complet sur Firebase (Auth + Firestore). Supabase,
  Edge Function, migrations SQL, clés et scripts Firebase Admin supprimés.
- Super-admin = compte Firebase vérifié (`taoficadebissi@gmail.com`) ; plus de
  geste caché ni de route ouverte. Codes d'invitation générés avec `Random.secure()`.
- Règles Firestore réécrites et testées (20 scénarios, émulateur).
- Fichiers/images : liens https (Storage indisponible sur Spark).
- CoursLibre extrait dans `../coursLibre` (projet Flutter web autonome).

## À faire par le propriétaire
1. Créer le projet Firebase de CoursLibre, activer Authentication (e-mail/mot de
   passe) + Firestore, puis dans `coursLibre/` : `flutterfire configure` pour
   remplacer `lib/firebase_options.dart` (actuellement une copie provisoire de
   celle de Gestion) et mettre à jour `.firebaserc`.
2. Créer et vérifier le compte super-admin dans les deux projets Firebase.
3. `firebase deploy --only firestore:rules,hosting` dans chaque projet.
4. Mettre à jour `urlGestionFormation` (`coursLibre/lib/core/config/app_config.dart`)
   si l'URL d'hébergement de Gestion change.
5. Pousser sur GitHub (voir README / consignes de la session).
