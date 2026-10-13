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

## Projet Firebase unique
Les deux applications partagent `gestion-de-formation-5b049`. Les règles
Firestore des deux vivent dans `gestion/firestore.rules` (seul fichier à
déployer). CoursLibre n'a que son site d'hébergement `courslibre-gf`.

## À faire par le propriétaire
1. Créer le site d'hébergement : `firebase hosting:sites:create courslibre-gf`.
2. Créer et vérifier le compte super-admin dans Firebase Authentication.
3. Déployer les règles (dossier gestion) puis chaque site.
4. Mettre à jour `urlGestionFormation` dans `coursLibre/lib/core/config/app_config.dart`
   si l'URL de Gestion change.
