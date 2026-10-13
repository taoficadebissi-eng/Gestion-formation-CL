# Gestion Formation

Plateforme multi-centres de gestion de formations (Flutter + Firebase) :
centres, formations, sessions, inscriptions, présences, paiements, notes de
cours (liens), chat de groupe et messagerie admin ↔ apprenant.

> CoursLibre (vitrine de cours gratuits) est un **projet séparé** (dossier frère
> `coursLibre/`, dépôt `courslibre`) mais partage ce projet Firebase : les règles
> Firestore des deux applications sont dans `firestore.rules` (ce dépôt) et
> CoursLibre n'a que son site d'hébergement.

## Stack
- Flutter (web, Android, Windows), Riverpod, GoRouter
- **Firebase Auth** (e-mail / mot de passe) + **Cloud Firestore**
- Plan Firebase **Spark** (gratuit) : ni Cloud Functions, ni Storage →
  les documents de cours et les images de couverture sont des **liens https**.

## Rôles
| Rôle | Accès |
|---|---|
| Super-admin | Compte Firebase dont l'e-mail est `taoficadebissi@gmail.com` **et vérifié**. Génère les codes d'invitation. Pas de profil dans `users`. |
| Admin | Propriétaire d'un ou plusieurs centres ; crée formateurs et apprenants ; enregistre les paiements. |
| Formateur | Son centre : formations, sessions, présences, notes. |
| Apprenant | Son centre : catalogue, inscription, présences, chat, notes (sauf si bloqué pour impayé). |

## Modèle de données (Firestore)
Collections : `centres`, `users`, `formations`, `sessions`, `inscriptions`,
`presences`, `paiements`, `notes`, `messages`, `messages_admin_conversations`,
`messages_admin`, `invitations`. Les champs sont en `snake_case`.

Ids déterministes (utilisés aussi par les règles) :
- inscription : `{apprenantId}_{formationId}` (empêche la double inscription)
- présence : `{sessionId}_{apprenantId}`
- conversation admin : `{centreId}_{apprenantId}_{adminId}`
- invitation : le code lui-même (`INV-XXXXX-XXXXX-XXXXX-XXXXX`)

## Sécurité — `firestore.rules`
- Isolation par centre ; les requêtes de liste incluent toujours `centre_id`.
- Inscription admin : le code d'invitation est **consommé dans le même batch**
  que la création du profil (`getAfter`) ; sans code valide, aucun profil
  admin/formateur ne peut être créé par l'utilisateur lui-même.
- Paiements : champs `statut_paiement`, `montant_paye`, `montant_restant`
  modifiables par l'admin propriétaire seulement ; une ligne `paiements` doit
  accompagner une hausse exacte de `montant_paye` (même batch).
- Un apprenant ne peut annuler son inscription que s'il n'a rien payé et n'est
  ni en retard ni bloqué.
- Un apprenant bloqué n'accède plus aux notes ni au chat de la formation.
- Codes d'invitation : lecture d'un code précis par un connecté, **liste et
  création réservées au super-admin**.

Tests des règles (émulateur, 20 scénarios) :
```bash
cd tests/rules && npm install
npx firebase-tools@13 emulators:exec --config ../../firebase.json \
  --only firestore --project demo-gestion "node --test rules.test.js"
```
(`firebase-tools` ≥ 14 exige Java 21 ; la version 13 fonctionne avec Java 17.)

## Mise en route
```bash
flutter pub get
flutter run -d chrome
flutter test
flutter build web --release   # toujours tester le build release
firebase deploy --only firestore:rules,hosting
```

## Première mise en service (à faire une fois)
1. Console Firebase → Authentication → créer le compte `taoficadebissi@gmail.com`.
2. Vérifier l'e-mail (lien de vérification, ou « mot de passe oublié » : terminer
   la réinitialisation vérifie l'adresse).
3. Déployer les règles : `firebase deploy --only firestore:rules`.
4. Se connecter dans l'application avec ce compte : on arrive sur l'espace
   super-admin, qui génère les codes d'invitation.
5. Un futur admin utilise « Activation du compte » avec son code.

## Limites connues
- Supprimer un utilisateur supprime son profil Firestore mais **pas** son compte
  Firebase Auth (impossible sans Admin SDK / Cloud Functions). Sans profil, il
  n'a accès à aucune donnée.
- Pas de stockage de fichiers (plan Spark) : documents et images par lien.

## Pièges connus
- Riverpod : ne jamais modifier un provider pendant le `build` d'un autre.
- GoRouter : un seul routeur (`routerProvider`) notifié via `refreshListenable`.
- Web : ne pas faire `await canLaunchUrl()` avant `launchUrl` (casse le geste utilisateur).
- Dart/dart2js : passer par `.toString()` pour les valeurs `dynamic` (enums).
- Toujours tester `flutter build web --release`, pas seulement le debug.
