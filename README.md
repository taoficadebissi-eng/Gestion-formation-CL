# 📚 Gestion Formation & CoursLibre — Documentation technique complète

Plateforme de gestion de centres de formation (multi-tenant) avec une vitrine publique
de cours gratuits (CoursLibre) construite par-dessus, sans modifier l'interface admin existante.

---

## 1. Vue d'ensemble

Ce dépôt contient **deux applications interconnectées** dans le même projet Flutter/Firebase :

| Application | Description | Statut |
|---|---|---|
| **Gestion Formation** | Plateforme multi-tenant de gestion de formations, sessions, formateurs et apprenants | En production |
| **CoursLibre** | Vitrine publique référençant des cours externes gratuits (Coursera, edX, Google, etc.) pour attirer des visiteurs | En ligne, pré-lancement (durcissement sécurité en cours) — refonte visuelle en cours |

Le développeur historique (Taofic) est actuellement seul développeur et super-admin du système.

### 🏗️ Architecture technique globale

- **Frontend** : Flutter (Dart) avec Riverpod pour la gestion d'état — **décision confirmée** : CoursLibre reste en Flutter (pas de migration vers un site HTML/CSS statique séparé, option évaluée puis écartée au profit d'un travail approfondi sur le design Flutter lui-même)
- **Backend** : Firebase (Authentication + Firestore)
- **Déploiement** : Firebase Hosting (Web) + APK Android
- **Routing** : GoRouter avec redirections intelligentes
- **Sécurité** : Règles Firestore multi-tenant
- **Plan Firebase Spark (gratuit)** — ⚠️ pas de carte bancaire enregistrée, pas de plan Blaze. Ceci conditionne de nombreux choix d'architecture (voir section 6)

**Environnement de développement de référence :** VS Code + PowerShell sous Windows, projet situé à `C:\gestion`.

### 👥 Rôles utilisateurs (Gestion Formation)

L'application gère 3 types d'utilisateurs avec des permissions distinctes, plus un accès Super Admin caché :

| Rôle | Accès | Responsabilités |
|------|-------|-----------------|
| **Admin** | Multi-centre | Gestion complète des centres, utilisateurs, formations |
| **Formateur** | Son centre | Création de formations, sessions, gestion des présences |
| **Apprenant** | Son centre | Inscription aux formations, suivi de présence |

**Rôle-based centreId resolution** :
- Les **admins** utilisent `centreActifProvider` (sélection multi-centre)
- Les **formateurs/apprenants** utilisent leur `profile.centreId` fixe
- Ne jamais confondre les deux : cause historique de bugs d'invisibilité silencieuse de données

**Accès super-admin** : 10 taps sur le logo de la page de connexion. Contourne Firebase Auth. La collection `invitations` est intentionnellement laissée ouverte (dette de sécurité acceptée temporairement — voir section 7).

---

## 2. Stack technique

- **Flutter / Dart** — framework applicatif (cible web, Android, Windows)
- **Riverpod** — gestion d'état
- **GoRouter** — navigation / routing
- **Cloud Firestore** — base de données
- **Firebase Hosting** — hébergement
- **`shared_preferences`** — cache local et suivi un-par-appareil
- **`flutter_staggered_animations`** — animations de grille de cartes CoursLibre
- **`url_launcher`** — liens externes vers les cours

---

## 3. Architecture & modules clés

```
lib/
└── features/
    └── cours_publics/
        ├── screens/
        │   ├── accueil_public_screen.dart      # Page d'accueil publique CoursLibre
        │   └── detail_cours_screen.dart        # Détail d'un cours
        ├── widgets/
        │   ├── modern_top_bar.dart              # Barre supérieure (logo, refresh, connexion)
        │   ├── modern_filter_bar.dart            # Filtres par catégorie
        │   ├── modern_course_card.dart           # Carte d'affichage d'un cours
        │   └── skeleton_carte_widget.dart        # Placeholder de chargement
        ├── providers/
        │   └── cours_publics_provider.dart       # FutureProvider + cache + refresh
        └── models/
            └── cours_gratuit_model.dart           # Modèle CoursGratuit (niveau = enum NiveauCours)
```

### État actuel du design CoursLibre (session en cours)

- **Page d'accueil (`accueil_public_screen.dart`)** : hero avec photo de fond (Unsplash, licence libre) + voile dégradé bleu/teal (`#1E3A8A` → `#0F766E`) pour la lisibilité du texte, conservant l'identité de marque. Barre de recherche flottante, filtres par catégorie, liste de cartes.
- **Cartes de cours (`modern_course_card.dart`)** : `StatefulWidget` avec effet de survol (soulèvement + ombre accentuée). En-tête avec image du cours (`lienImage`) si disponible en Firestore, sinon dégradé de secours teinté par niveau. Badge "Certificat gratuit" et nom du fournisseur en overlay sur l'image. Bouton "Voir le cours" qui se transforme en pilule pleine au survol.
- **Page détail (`detail_cours_screen.dart`)** : `StatefulWidget` avec animations d'entrée échelonnées (fondu + glissement) section par section — bannière, informations, description, bouton. Bannière photo en haut (même logique `lienImage` que les cartes). Bouton d'action final en dégradé de marque avec effet de survol (élévation, ombre, icône qui glisse).
- **Point d'attention** : si les documents `cours_gratuits` n'ont pas de `lienImage` renseigné, le dégradé de secours s'affiche partout — fonctionnel mais moins riche visuellement que de vraies vignettes par fournisseur.

---

## 4. Fonctionnalités — Gestion Formation

### 🔐 Authentification et sécurité

- ✅ **Authentification Firebase** : Email/Mot de passe sécurisé
- ✅ **Super Admin caché** : Accès par 10 taps sur le logo de la page de connexion
- ✅ **Codes d'invitation** : Système de tokens à usage unique pour créer des comptes admin
- ✅ **Mot de passe temporaire** : Changement obligatoire à la première connexion
- ✅ **Mot de passe oublié** : Réinitialisation par email
- ✅ **Validation emails flexible** : Accepte tous les domaines (gmail, outlook, yahoo, etc.)

### 🏢 Gestion multi-centre

- ✅ **Multi-centre par admin** : Un admin peut gérer plusieurs centres
- ✅ **Isolation totale des données** : Chaque centre voit uniquement ses propres données
- ✅ **Création de centre** : Nom, ville, pays
- ✅ **Sélection de centre** : Interface de choix pour les admins multi-centres
- ✅ **Nom du centre affiché** : Badge dans l'AppBar de chaque dashboard

### 👤 Gestion des utilisateurs

- ✅ **Création d'utilisateurs** : Admin crée formateurs et apprenants
- ✅ **Page succès** : Affichage des coordonnées avec bouton copier
- ✅ **Rôles** : Formateur ou Apprenant
- ✅ **Liste des utilisateurs** : Filtrage par centre
- ✅ **Suppression** : Contrôle par rôle

### 📖 Gestion des formations

- ✅ **Catalogue** : Liste de toutes les formations
- ✅ **Création** : Titre, description, niveau, dates, nombre de sessions
- ✅ **Modification** : Édition de toutes les informations
- ✅ **Suppression** : Avec confirmation
- ✅ **Nom du formateur** : Affiché dans les détails
- ✅ **Niveaux** : Débutant, Intermédiaire, Avancé
- ✅ **Format de dates** : jj/mm/aaaa (bug "//" corrigé)

### 📅 Gestion des sessions

- ✅ **Sessions par formation** : Ajout de sessions avec date, heure, salle
- ✅ **Calendrier** : Visualisation des sessions
- ✅ **Sessions du jour** : Mise en évidence des sessions actuelles

### 📝 Inscriptions et présences

- ✅ **Inscription apprenant** : Auto-inscription depuis le catalogue
- ✅ **Protection double inscription** : Impossible de s'inscrire 2 fois à la même formation
- ✅ **Désinscription** : L'apprenant peut se désinscrire
- ✅ **Feuilles de présence** : Gestion par le formateur
- ✅ **Taux de présence** : Calcul automatique et affichage

### 🎨 Interface utilisateur

- ✅ **Splash screen** : Écran de chargement au démarrage
- ✅ **Dashboards personnalisés** : Interface adaptée à chaque rôle
- ✅ **Bannière hors ligne** : Détection de la connexion
- ✅ **Design moderne** : Interface épurée avec couleurs cohérentes
- ✅ **Responsive** : Adapté mobile, tablette et desktop
- ✅ **Multi-plateforme** : Web, Android, Windows

### CoursLibre (public)

- ✅ Page d'accueil publique avec hero, recherche, filtres par catégorie
- ✅ Cartes de cours avec animations et effets de survol (voir section 3)
- ✅ Page de détail avec animations d'entrée et bouton d'accès externe
- ✅ Lien "Connexion" redirigeant vers le login de l'app Gestion Formation
- 🔄 Compteur de visiteurs (Firestore custom counter) — en cours d'implémentation
- 🔄 Footer sur la page d'accueil — en cours d'implémentation

---

## 5. Comment utiliser l'application (Gestion Formation)

### 📥 Installation

#### Version Web
1. Accédez à l'URL de déploiement Firebase Hosting
2. Connectez-vous avec vos identifiants
3. Aucune installation nécessaire

#### Version Android
1. Téléchargez le fichier APK : `build\app\outputs\flutter-apk\app-release.apk`
2. Autorisez l'installation depuis sources inconnues
3. Installez l'application
4. Lancez-la depuis votre écran d'accueil

### 🔑 Première connexion (Admin)

1. **Obtenir un code d'invitation** :
   - Le Super Admin doit générer un code via l'interface cachée (10 taps sur le logo)
   - Le code est à usage unique
2. **Créer son compte** :
   - Aller sur la page "Activation du compte"
   - Entrer le code d'invitation
   - Remplir nom, prénom, email, mot de passe
   - Valider
3. **Créer son premier centre** :
   - Après connexion, redirection automatique vers "Créer un centre"
   - Entrer nom, ville, pays du centre
   - Valider
4. **Accéder au dashboard** :
   - Redirection automatique vers le tableau de bord admin
   - Le nom du centre s'affiche en haut à gauche

### 👨‍🏫 Création d'un formateur ou apprenant

1. Aller dans "Gérer les utilisateurs"
2. Cliquer sur "Créer un utilisateur"
3. Choisir le rôle (Formateur ou Apprenant)
4. Remplir les informations
5. Définir un mot de passe temporaire (minimum 6 caractères)
6. Valider
7. **Page succès** : Les coordonnées sont affichées avec un bouton copier
8. Transmettre les identifiants à l'utilisateur

### 🎓 Première connexion (Formateur/Apprenant)

1. Se connecter avec les identifiants fournis
2. **Redirection automatique** vers la page "Créer votre mot de passe"
3. Entrer un nouveau mot de passe personnel
4. Confirmer le mot de passe
5. Valider
6. Redirection vers le dashboard approprié

### 📱 Utilisation quotidienne

**Pour l'Admin** — Dashboard (vue d'ensemble formations/apprenants/formateurs), actions rapides, gestion complète du centre.

**Pour le Formateur** — Dashboard "Mes formations" avec statistiques, création de formations, gestion des sessions, feuilles de présence.

**Pour l'Apprenant** — Espace personnel (formations inscrites), taux de présence en temps réel, catalogue, détails formation.

---

## 6. Contraintes liées au plan Spark (gratuit)

Le plan Firebase Spark impose des choix d'architecture à respecter impérativement :

- **Pas de Firebase Storage** → utiliser des liens externes ou du cache local
- **Cache local** via `shared_preferences` plutôt que des solutions cloud payantes
- **Compteur de visiteurs** implémenté via un compteur custom Firestore (1 écriture par incrément, 1 incrément par appareil par jour via `shared_preferences`) plutôt que Firebase Analytics, pour un contrôle total des coûts
- Toute nouvelle fonctionnalité doit être évaluée à l'aune du volume d'écritures/lectures Firestore généré

---

## 7. Pièges connus & bonnes pratiques (à ne PAS réintroduire)

Ces bugs ont déjà été rencontrés et corrigés. Toute régression future doit être vérifiée contre cette liste.

### Riverpod
- **Ne jamais appeler `ref.read(...notifier).state` pendant un cycle de build d'un provider** → boucle infinie de crash
- `centreIdActifProvider` doit rester un provider de lecture pure (computed), jamais un point d'écriture

### Flutter Web — pièges spécifiques
- `Spacer()` dans une `Column` à l'intérieur d'un `SliverList` non borné → crash de layout silencieux. Utiliser `SizedBox` + `mainAxisSize.min` à la place
- `await canLaunchUrl()` casse la chaîne de gesture utilisateur sur web, bloquant les popups `url_launcher` → appeler `launchUrl` directement avec `webOnlyWindowName: '_blank'`
- `shared_preferences` peut lever `MissingPluginException` en production si `flutter clean` n'a pas été exécuté avant un rebuild — même piège rencontré avec `file_picker` (`UnimplementedError`/`LateInitializationError` au premier appel) après une mise à jour de version majeure : la génération des plugins web reste périmée tant qu'un `flutter clean` + `flutter pub get` n'a pas été fait
- **Symptôme "rien ne s'affiche, même pas de page blanche, rien dans la console"** en `flutter run -d chrome` : souvent un ancien processus qui bloque le port de debug (fermer complètement Chrome + terminal, `flutter clean`, relancer). Si le blocage persiste après un fichier modifié, isoler en restaurant temporairement l'ancienne version du fichier pour confirmer/infirmer la cause.

### Typage dynamique / dart2js (cause de bug déjà rencontrée)
- Un champ modèle typé comme **enum** (ex : `niveau` est un `NiveauCours`, pas une `String`) assigné sans conversion explicite à une variable `String` dans un widget qui manipule du `dynamic` peut fonctionner en debug (DDC) mais **planter uniquement en build release** (`flutter build web`) avec une erreur du type `NoSuchMethodError: method not found: 'toLowerCase'`
- **Règle** : dans tout widget qui reçoit du `dynamic` (ex : `ModernCourseCard`), toujours passer par `.toString()` avant tout appel de méthode `String` (`.toLowerCase()`, `.contains()`, etc.), ou entourer les accès à des champs potentiellement absents d'un `try/catch`
- Toujours tester un build release (`flutter build web`) avant de livrer, pas seulement `flutter run` en debug

### GoRouter
- Toute route non authentifiée doit être explicitement ajoutée à `isPublicRoute`, sinon le router redirige même le super-admin vers `/connexion`
- **Ne jamais appeler `GoRouter(...)` (ou toute fabrique qui le fait) à l'intérieur d'un `build()` réactif** (ex: `AppRouter.createRouter(user:, isLoading:, centres:)` invoqué dans `MyApp.build()`, avec ces paramètres capturés depuis `ref.watch(...)`). Un **nouveau** `GoRouter` recréé à chaque changement de provider réinitialise toute la pile de navigation à `initialLocation` et relance `redirect` avec l'état du moment, parfois transitoire — observé concrètement avec les streams realtime Supabase (assez fréquents) : un admin qui vient de créer un formateur pouvait atterrir un instant sur `/changer-mot-de-passe` (car le state lu par le redirect reflétait transitoirement le nouvel utilisateur). **Corrigé** en créant le `GoRouter` une seule fois via un `Provider<GoRouter>` (`routerProvider` dans `app_router.dart`), notifié des changements via `refreshListenable` (un `ChangeNotifier` qui `ref.listen()` les providers concernés), le `redirect` lisant l'état courant via `ref.read(...)` à chaque évaluation plutôt que de recevoir des valeurs figées en paramètres.

### Supabase (remplace Firebase Auth + Firestore depuis la refonte)
- **Un `SupabaseClient` secondaire (pattern "l'admin crée un autre compte sans perdre sa session") doit être construit avec `authOptions: AuthClientOptions(authFlowType: AuthFlowType.implicit)`.** Le flow PKCE (par défaut) exige un `pkceAsyncStorage` que seul `Supabase.initialize()` fournit pour le client principal ; sans lui, `signUp()` plante sur un null-check interne à `gotrue` (`_asyncStorage!.setItem(...)`), silencieusement absorbé par le `catch` de l'écran appelant.
- **Ne pas appeler `signOut()` sur ce client secondaire.** Constaté empiriquement (pas encore totalement expliqué au niveau du SDK) : sur le client Flutter principal (`Supabase.instance.client`, câblé par `Supabase.initialize()`), un `signOut()` effectué sur le client secondaire finissait par déclencher la suppression de la session admin persistée dans `localStorage` (clé `sb-<ref>-auth-token`, commune à tout client pointant vers le même projet). `dispose()` seul suffit : ce client jetable n'a de toute façon aucune session persistée à nettoyer.
- Le stream realtime (`.stream(primaryKey: [...])`) n'accepte qu'un seul `.eq()` côté serveur, contrairement à Firestore qui accepte des `where()` combinés — filtrer sur le champ le plus sensible côté serveur (`centre_id`, aligné avec la partition RLS) et affiner côté client dans le `.map()` pour un second critère.
- Penser à désactiver "Confirm email" dans Authentication > Providers > Email : sans ça, `signUp()` ne renvoie pas de session immédiate, cassant le flux existant (mot de passe temporaire, changement obligatoire à la première connexion, sans étape de confirmation).
- **Edge Functions** : importer `@supabase/supabase-js` via `https://esm.sh/...` peut faire planter la fonction au démarrage sur le runtime Deno, sans message d'erreur exploitable côté client (juste un `401 Invalid credentials` générique, identique avec ou sans token — vérifier les logs de la fonction dans le Dashboard : `event_type: Shutdown`, `reason: EarlyDrop` confirme un échec de démarrage, pas un vrai rejet d'auth). Utiliser `jsr:@supabase/supabase-js@2` à la place.

### Cache & UI
- Appeler `refreshCoursProvider()` après tout ajout/suppression Firestore, sinon l'UI ne se met pas à jour
- Le filtre "Tous" doit utiliser une méthode dédiée retournant `null`, jamais la chaîne littérale `"Tous"`, sous peine de ne pas réinitialiser correctement les filtres

### Firestore Security Rules
- Éviter les wildcards globaux type `allow read: if request.auth != null`
- Utiliser des fonctions helper scopées par rôle (`estProprietaireCentre`/`canAccessCentre`, `accesCentreAutorise`)
- La propriété d'un centre par un admin se vérifie via `get(/databases/.../centres/$(centreIdDoc)).data.adminId == request.auth.uid`, car les admins ont un `centreId` vide sur leur propre document utilisateur

### Environnement de dev
- Les faux positifs "file not found" dans VS Code/Dart Analysis Server se résolvent avec `flutter clean` + redémarrage du Dart Analysis Server
- PowerShell : les écritures de fichiers utilisent la syntaxe heredoc `@'...'@` avec `Set-Content` ; **ne pas utiliser d'accents dans les chaînes PowerShell**

---

## 8. Dette technique connue (à traiter avant lancement public élargi)

- **Collection `invitations` ouverte** : permet actuellement le listing en masse des tokens. Risque accepté temporairement, à corriger avant un lancement public élargi
- **Auto-inscription en rôle admin** : ne peut pas être empêchée uniquement via les règles Firestore. Nécessite des Cloud Functions (Admin SDK) — implique de passer au plan Blaze (voir contrainte Spark, section 6)
- **Collection `cours_gratuits` en écriture ouverte** : même logique que `invitations` (accès super-admin caché par geste dans l'app, pas par authentification Firebase) — risque accepté temporairement

---

## 9. Fonctionnalités à ajouter / Roadmap

### 🎯 Priorité haute

- [ ] **Notifications push** : Alertes pour nouvelles sessions, rappels
- [ ] **Export PDF** : Feuilles de présence, listes d'inscrits
- [ ] **Export Excel/CSV** : Rapports statistiques
- [ ] **Calendrier interactif** : Vue mensuelle des sessions
- [ ] **Recherche avancée** : Filtrage par nom, date, niveau
- [ ] **CoursLibre — Footer** sur `accueil_public_screen.dart`
- [ ] **CoursLibre — Compteur de visiteurs** (Firestore custom counter + `shared_preferences`)
- [ ] **CoursLibre — Vignettes fournisseur** : logos officiels (Coursera, edX, Google...) à intégrer via `lienImage`

### 🎨 Priorité moyenne

- [ ] **Mode sombre/clair** : Thème personnalisable
- [ ] **Photo de profil** : Upload et gestion d'avatar
- [ ] **Chat interne** : Communication entre formateurs et apprenants
- [ ] **Ressources pédagogiques** : Upload de documents par formation
- [ ] **Évaluations** : Quiz et notes pour les apprenants

### 🔧 Priorité basse

- [ ] **Statistiques avancées** : Graphiques, tendances, rapports
- [ ] **Intégration Google Calendar** : Synchronisation des sessions
- [ ] **Paiement en ligne** : Gestion des frais d'inscription
- [ ] **Certificats** : Génération automatique de certificats
- [ ] **API publique** : Intégration avec d'autres systèmes
- [ ] **Multi-langue** : Support anglais, français, etc.

### 🛡️ Améliorations techniques

- [ ] **Tests unitaires** : Couverture de code complète
- [ ] **Tests d'intégration** : Validation des flux complets
- [ ] **Documentation API** : Swagger/OpenAPI
- [ ] **Monitoring** : Logs et analytics
- [ ] **Sauvegarde automatique** : Backup des données Firestore
- [ ] **PWA** : Progressive Web App pour installation mobile

### Sur l'horizon (dette & sécurité)

- Wider public launch de CoursLibre (actuellement en ligne mais pré-lancement côté sécurité)
- Traitement des dettes techniques de la section 8
- Raffinement du workflow multi-outils IA (voir section 10)

---

## 10. Workflow multi-outils IA — ⚠️ point de vigilance critique

Ce projet a été développé avec l'assistance simultanée de **plusieurs outils IA** (Claude, DeepSeek R1, Qwen/GLM, et plus récemment Gemini), ce qui a déjà causé des **conflits de fichiers et des régressions silencieuses** (exemple réel : suppression du bouton de rafraîchissement et introduction d'un bug de typage lors d'une session d'amélioration UI via Gemini).

**Règles à suivre impérativement pour toute nouvelle équipe/collaborateur reprenant le projet :**

1. **Toujours demander/vérifier le contenu actuel d'un fichier avant de le modifier**, même si vous pensez le connaître — un autre outil ou une autre personne a pu le modifier entre-temps
2. **Toujours tester un build release complet (`flutter build web`) avant de considérer une modification UI comme terminée** — de nombreux bugs de typage n'apparaissent qu'en release, pas en debug
3. **Documenter chaque session de travail** via un document de handoff (pattern `HANDOFF_<sujet>.md`) pour assurer la continuité entre sessions/personnes
4. Si plusieurs personnes/outils travaillent en parallèle sur le même module, **signaler explicitement** qui a touché quoi, quand

**Prompts pour DeepSeek** (génération de code secondaire) : toujours inclure le contexte d'architecture, les fichiers existants pertinents, le résultat exact attendu, et les contraintes PowerShell (pas d'accents, syntaxe heredoc).

---

## 11. Statistiques du projet

- **Durée de développement** : Phase complète de conception à déploiement
- **Lignes de code** : ~15 000+ lignes Dart
- **Écrans** : 20+ écrans Flutter
- **Collections Firestore** : 8 (centres, users, formations, sessions, inscriptions, presences, invitations, cours_gratuits)
- **Rôles** : 3 (admin, formateur, apprenant) + Super Admin
- **Plateformes** : Web, Android, Windows

---

## 12. Mise en route pour une nouvelle équipe

```powershell
# Cloner le projet (chemin de référence historique : C:\gestion)
cd C:\gestion

# Installer les dépendances
flutter pub get

# Lancer en dev (web)
flutter run -d chrome

# ⚠️ Avant toute mise en production, TOUJOURS tester le build release :
flutter clean
flutter build web
```

### Prérequis

```bash
flutter --version  # 3.x minimum
firebase --version # 13.x minimum
```

**Accès Firebase** : projet sur plan Spark (gratuit). Toute évolution nécessitant Cloud Functions, Storage ou des quotas plus élevés implique une décision consciente de passer au plan Blaze, à valider avec le porteur du projet.

**Accès super-admin** : pattern de geste caché (10 taps sur le logo, non documenté publiquement pour des raisons de sécurité — à demander directement au porteur du projet).

---

## 13. Contacts & continuité

- **Porteur de projet / développeur historique** : Taofic
- **Historique de développement** : sessions avec Claude (architecture + implémentation principale, y compris la refonte visuelle de CoursLibre), DeepSeek R1 et Qwen/GLM (génération de code secondaire), Gemini (tentative d'amélioration UI ayant nécessité des correctifs)
- **Pattern de documentation** : documents de handoff `HANDOFF_*.md` à consulter/produire pour toute passation

---

*Ce README doit être mis à jour à chaque changement d'architecture significatif ou levée de dette technique majeure (section 8).*

---

## Avancement de la refonte

Suivi de la refonte décrite dans le cahier des charges "Refonte de Gestion Formation". Chaque case est cochée uniquement une fois l'étape terminée, testée, et le code compile sans erreur, avec la date de complétion.

> ⚠️ **Décision utilisateur (2026-08-29)** : le blocage plan Spark/Blaze (Firebase Storage + Cloud Functions requis pour les Phases 3, 5, 7) est résolu en migrant Gestion Formation de Firebase (Auth + Firestore + Storage) vers **Supabase** (Postgres + Auth + Storage + Edge Functions), migré au fil des phases plutôt qu'en un bloc. La vitrine publique CoursLibre (`cours_gratuits`, compteur de visiteurs) reste sur Firebase, hors périmètre. Voir `NOTES_AUDIT.md` section 6 et `supabase/migrations/`.

### Phase 0bis — Migration des fondations vers Supabase
- [x] Ajout du package `supabase_flutter`, initialisation dans `main.dart` (Firebase conservé en parallèle pour CoursLibre) — 2026-08-29
- [x] Schéma Postgres + RLS pour `centres`, `profiles`, `formations`, `sessions`, `inscriptions`, `presences`, `invitations` (`supabase/migrations/0001_foundations.sql`) — 2026-08-29
- [x] Migration SQL exécutée par l'utilisateur dans le Supabase SQL Editor (projet `xuvvqkwjkxnyafrqxgta`) — 2026-08-29
- [x] "Confirm email" désactivé dans Authentication > Providers > Email — 2026-08-29
- [x] Migration de tous les modèles (`lib/models/`) : Firestore `Timestamp` → `timestamptz` ISO8601, clés JSON en snake_case — 2026-08-29
- [x] Migration de tous les services (`auth_service`, `user_service`, `centre_service`, `formation_service`, `inscription_service`, `presence_service`, `session_service`) de Firestore vers Supabase (Postgrest + Realtime), signatures publiques inchangées pour ne pas impacter providers/écrans — 2026-08-29
- [x] Migration de `auth_provider.dart` / `user_provider.dart` (type `Session?` de Supabase au lieu de `User?` Firebase) — 2026-08-29
- [x] Migration de `super_admin_screen.dart` (gestion des invitations) vers Supabase, section cours gratuits laissée sur Firestore — 2026-08-29
- [x] `flutter analyze` : aucune erreur (warnings pré-existants uniquement, dans CoursLibre, hors périmètre) — 2026-08-29
- [x] `flutter build web` (build release) : succès — 2026-08-29
- [x] Test fonctionnel réel via l'API REST Supabase (contournant l'UI Flutter, non lancée dans cet environnement) : création d'un code d'invitation, lecture par token, inscription admin avec session immédiate, écriture du profil, marquage du code comme utilisé, création d'un centre par l'admin, création d'un profil formateur par l'admin dans son centre — tout fonctionne conformément aux policies RLS. Données de test nettoyées après coup (2 comptes Auth de test restent dans Authentication > Users, à supprimer manuellement si besoin — pas de clé service_role disponible pour le faire par script) — 2026-08-29
- [x] Mise à jour README (cette section) — 2026-08-29

### Phase 0 — Préparation
- [x] Lire l'ensemble du code source actuel (écrans, modèles de données, structure Firestore réelle, règles de sécurité actuelles) — 2026-08-29
- [x] Lister dans `NOTES_AUDIT.md` : collections Firestore, écrans existants, dépendances installées — 2026-08-29
- [x] Identifier les packages Flutter à ajouter pour la suite (upload, chat, Mobile Money) — 2026-08-29
- [x] Créer le squelette du README avec la checklist complète — 2026-08-29

### Phase 1 — Navigation par rôle (bottom navigation bar)
- [x] Widget de bottom navigation réutilisable selon le rôle (`lib/core/widgets/app_bottom_nav.dart`) — 2026-08-29
- [x] Admin : 4 onglets (Accueil / Formations / Utilisateurs / Messages) — `AdminShellScreen`, Accueil = résumé (stats), sans les anciennes "Actions rapides" désormais redondantes avec les onglets — 2026-08-29
- [x] Formateur : écran Accueil formateur (sessions du jour/à venir, nouveau) + Mes formations (réutilise `DashboardFormateurScreen`) + Messages — `FormateurShellScreen` — 2026-08-29
- [x] Apprenant : écran Mes formations (réutilise `EspaceApprenantScreen`, lecture seule) + Paiements (placeholder, Phase 5) + Messages (placeholder, Phase 6) — `ApprenantShellScreen` — 2026-08-29
- [x] Suppression de l'ancien dashboard à boutons empilés (`dashboard_screen.dart`), validée sur les 3 rôles avant suppression — 2026-08-29
- [x] Vérification déconnexion / changement de rôle / affichage nom-centre : testé en conditions réelles (voir ci-dessous) — 2026-08-29
- [x] Mise à jour README — 2026-08-29

**Test fonctionnel réel** (cette fois via un vrai navigateur piloté, `flutter build web` servi localement + Chrome headless, pas seulement l'API REST) : inscription admin par code d'invitation, création de centre, création d'un formateur et d'un apprenant par l'admin (avec changement de mot de passe obligatoire à leur première connexion), les 4 onglets admin, les 3 onglets formateur, les 3 onglets apprenant, et la déconnexion (session bien supprimée du `localStorage`) — tous vérifiés par capture d'écran, sans erreur console. Deux bugs réels ont été trouvés et corrigés au passage (voir section 7, "Supabase" et "GoRouter") :
1. Le client Supabase secondaire (création de compte par l'admin) plantait sur le flow PKCE, empêchant la création du compte.
2. Le `GoRouter` était recréé à chaque changement de provider au lieu d'être créé une seule fois, ce qui pouvait faire atterrir l'admin sur `/changer-mot-de-passe` juste après avoir créé un utilisateur.

### Phase 2 — Restructuration du schéma (Supabase/Postgres)
> Cahier écrit pour Firestore ("sous-collections") ; l'équivalent naturel sur Postgres est une table séparée + clé étrangère — voir le commentaire d'architecture en tête de `supabase/migrations/0002_phase2.sql`.
- [x] `prerequis_id` sur `formations` — 2026-08-29
- [x] Table `notes` (`formation_id`, `nom_fichier`, `url`, `uploade_par`, `date_ajout`) — 2026-08-29
- [x] Champs paiement sur `inscriptions` (`statut_paiement`, `montant_paye`, `montant_restant`), protégés par un trigger (voir section 7 "Supabase") — 2026-08-29
- [x] Table `paiements` (FK vers `inscriptions`) — 2026-08-29
- [x] `frais_total` sur `formations` — 2026-08-29
- [x] Table `messages` (chat de groupe par formation) — 2026-08-29
- [x] Tables `messages_admin_conversations` (participants[]) + `messages_admin` — 2026-08-29
- [x] Pas de script de migration séparé nécessaire : valeurs par défaut sur `ADD COLUMN`, appliquées automatiquement par Postgres — 2026-08-29
- [x] Policies RLS (notes, inscriptions, paiements, messages, messagesAdmin) dans `0002_phase2.sql` — 2026-08-29
- [x] Migration exécutée et vérifiée par l'utilisateur dans le SQL Editor Supabase — 2026-08-29
- [x] Mise à jour README — 2026-08-29

### Phase 3 — Upload de notes de cours (formateur)
- [x] Section "Notes de cours" sur le détail formation (`NotesSection`, visible pour tous les rôles autorisés) — 2026-08-29
- [x] Upload vers Supabase Storage (bucket `notes`, chemin `formations/{id}/notes/{fileId}_{nom}`, migration `0003_phase3_storage.sql`) — 2026-08-29
- [x] Création de la ligne `notes` à l'upload réussi — 2026-08-29
- [x] Affichage lecture seule côté apprenant + ouverture/téléchargement (URL signée à la demande, bucket privé) — 2026-08-29
- [x] Gestion des erreurs (fichier trop lourd, type non autorisé, pas de connexion) via `BlurredToast` — 2026-08-29
- [x] Migration `0003_phase3_storage.sql` exécutée par l'utilisateur — 2026-08-29
- [x] Test réel (navigateur piloté, formateur authentifié) : upload d'un PDF, apparition immédiate dans la liste avec icône/nom/date, toast de succès — 2026-08-29
- [x] Mise à jour README — 2026-08-29

### Phase 4 — Liaison entre formations (prérequis)
- [x] Champ "Formation prérequise" à la création/édition (`PrerequisSelector`, admin/formateur) — 2026-08-29
- [x] Enregistrement dans `prerequis_id` — 2026-08-29
- [x] Affichage du prérequis dans le détail formation (carte cliquable vers sa propre fiche) — 2026-08-29
- [x] Avertissement non bloquant à l'inscription si le prérequis n'est pas validé (l'apprenant n'a pas d'inscription existante dessus) — 2026-08-29
- [x] Testé en conditions réelles (navigateur piloté) : création de 2 formations liées, affichage correct du prérequis au détail et pré-sélection dans le formulaire d'édition, dialogue d'avertissement affiché avec le bon nom de formation à l'inscription — 2026-08-29
- [x] Mise à jour README — 2026-08-29

### Phase 5 — Paiements et statut de solde
- [x] Écran apprenant "Paiements" (`PaiementsApprenantScreen`) : solde par formation suivie, historique (bottom sheet), bouton "Payer" désactivé si solde nul — 2026-08-29
- [x] Écran admin : détail paiement d'un apprenant inscrit (`DetailPaiementSheet`, ouvert depuis `inscrits_screen.dart`) — solde, historique, enregistrement d'un paiement manuel, bascule bloqué/débloqué — 2026-08-29
- [x] Bouton "Payer maintenant" côté apprenant : UI préparée, ouvre une boîte de dialogue d'attente ("bientôt disponible") — l'intégration Mobile Money réelle (Fedapay/KKiaPay) reste une sous-étape séparée, en attente de la clé API du fournisseur choisi — 2026-08-29
- [x] Edge Function `enregistrer-paiement` écrite (`supabase/functions/enregistrer-paiement/index.ts`) : vérifie que l'appelant est admin propriétaire du centre, crée le paiement, recalcule `montant_paye`/`montant_restant`/`statut_paiement` en `service_role` — seul chemin habilité à écrire ces champs (voir trigger `prevent_direct_payment_change`, section 7) — 2026-08-29
- [x] Mécanisme de blocage manuel `statut_paiement = bloque` par l'admin (`togglerBlocage`, écriture directe autorisée par le trigger pour l'admin propriétaire) — 2026-08-29
- [x] Restriction d'accès (notes + chat) si `bloque`, vérifiée côté RLS (migration `0004_phase5_blocage.sql`, pas seulement côté UI) + message clair affiché à l'apprenant dans `NotesSection` — 2026-08-29
- [x] Migration `0004_phase5_blocage.sql` exécutée par l'utilisateur — 2026-08-29
- [x] Edge Function `enregistrer-paiement` déployée. **Bug de déploiement corrigé au passage** : l'import `https://esm.sh/@supabase/supabase-js@2` faisait planter la fonction au démarrage sur le runtime Deno des Edge Functions (logs : `event_type: Shutdown`, `reason: EarlyDrop` — la fonction ne bootait jamais, d'où un rejet générique `401 Invalid credentials` identique quel que soit le token envoyé). Remplacé par l'import recommandé `jsr:@supabase/supabase-js@2` — 2026-08-29
- [x] Test réel via l'API (deux appels successifs à la fonction, avec un vrai token admin) : paiement partiel (20000/50000, statut reste `a_jour`, `montant_restant` correct), puis paiement soldant le reste (statut passe bien à `a_jour` avec `montant_restant = 0`), ligne créée dans `paiements` à chaque fois — 2026-08-29
- [x] Test réel du blocage (via API, avec les vrais comptes admin/apprenant) : message de groupe visible par l'apprenant avant blocage, invisible immédiatement après passage à `statut_paiement = bloque` (RLS), débloqué ensuite — 2026-08-29
- [x] Mise à jour README — 2026-08-29

### Phase 6 — Messagerie
- [x] Chat de groupe par formation (temps réel) — `GroupChatScreen`, accessible depuis le détail formation ("Discussion du groupe", visible pour inscrit/formateur/admin), et depuis l'onglet Messages du formateur (liste de ses formations) — 2026-08-29
- [x] Messagerie admin ↔ apprenant (1-à-1) — `ApprenantMessagesTab` (conversation unique, créée à la volée), `AdminConversationsScreen` (liste des conversations) + `AdminChatScreen` — 2026-08-29
- [x] Badge de messages non lus sur l'onglet Messages (point rouge, suivi de la dernière lecture en local via `shared_preferences` — pas de champ dédié en base, "simple compteur" au sens du cahier) — 2026-08-29
- [x] Testé en conditions réelles (navigateur piloté) : envoi et réception d'un message de groupe (admin), envoi d'un DM apprenant → admin, réception confirmée côté admin avec le bon nom et aperçu du dernier message, badge non lu affiché sur l'onglet Messages de l'admin — 2026-08-29
- [x] Mise à jour README — 2026-08-29

### Phase 7 — Design et forme
- [x] Cohérence visuelle des écrans restructurés : réutilisation systématique de `AppColors`/`AppTheme.softCard`/`BlurredToast` sur tous les écrans créés dans les Phases 1 à 6, pas de style ad-hoc introduit — 2026-08-29
- [x] Image de formation : sélecteur `FormationImagePicker` (création + édition), upload vers le bucket `formations-images` (public, migration `0005_phase7_image_formation.sql`), affichage en vignette dans le catalogue et en en-tête (avec voile sombre pour la lisibilité) dans le détail formation — 2026-08-29
- [x] Amélioration continue de la structure des écrans au fil des phases (fait phase par phase, pas en un seul passage global — ex: flèches retour obsolètes corrigées dès leur détection en Phase 1bis) — 2026-08-29
- [x] Migration `0005_phase7_image_formation.sql` exécutée par l'utilisateur — 2026-08-29
- [x] Test réel (navigateur piloté) : upload d'une image de couverture depuis le formulaire de modification, aperçu immédiat dans le formulaire, puis affichage confirmé en vignette dans le catalogue après enregistrement — 2026-08-29
- [x] Mise à jour README — 2026-08-29
- [x] **Refonte marquée terminée** (2026-08-29) : toutes les phases du cahier des charges (1 à 8) sont implémentées et validées par des tests réels (navigateur piloté et/ou API directe avec les vraies policies RLS). Seule l'intégration Mobile Money réelle (Fedapay/KKiaPay) reste hors périmètre, en attente d'une clé API fournisseur — l'UI est prête à la recevoir.

**Bug bloquant supplémentaire trouvé et corrigé pendant les tests de cette phase** : `file_picker` (upload de notes ET d'images) échouait systématiquement sur le web avec `UnimplementedError` après la mise à jour de la dépendance de la v8 à la v12 (nécessaire pour corriger un premier bug, `LateInitializationError`, sur l'ancienne version). Cause : cache de génération des plugins web périmé après un changement de dépendance majeur — piège déjà documenté dans ce README (section 7) pour `shared_preferences`, qui s'applique donc aussi à `file_picker`. Résolu par `flutter clean` + `flutter pub get` + rebuild.

### Phase 8 — Harmonisation des notifications (toasts)
> Traitée maintenant (avant la Phase 2), à la demande de l'utilisateur, pour que les écrans des phases suivantes utilisent `BlurredToast` dès leur création plutôt que d'être retouchés après coup — voir la "Note d'ordonnancement" du cahier des charges.
- [x] Création de `lib/widgets/blurred_toast.dart` (code de l'annexe, non modifié) — 2026-08-29
- [x] Recensement de tous les appels `SnackBar`/`showSnackBar` existants (32 occurrences, 14 fichiers) — 2026-08-29
- [x] Remplacement par `BlurredToast.show(context, "...")` — 2026-08-29
- [x] Icônes pertinentes selon le type de message (succès `check_circle_outline`, erreur `error_outline`, info `info_outline`, copie `copy_rounded`, suppression `delete_outline`) — 2026-08-29
- [x] Vérification qu'aucun `SnackBar` natif ne subsiste (`grep -rn "showSnackBar\|SnackBar(" lib` : 0 résultat) — 2026-08-29
- [x] Test visuel réel (navigateur piloté) : toast affiché correctement après création de centre — 2026-08-29
- [x] Mise à jour README — 2026-08-29

**Bonus (corrections signalées par l'utilisateur après test manuel avec `flutter run`)** :
- [x] **Bug bloquant** : après la création du premier centre par un admin, l'app restait bloquée sur l'écran "Créer un centre" au lieu de naviguer vers le dashboard. Cause : le stream réaltime `centresDuAdminProvider` n'avait pas encore reçu la mise à jour au moment où `redirect` s'évaluait pour `/admin/dashboard`, renvoyant vers `/centre/creer` — route qui n'avait aucune règle de sortie une fois les centres effectivement chargés. Règle de redirection ajoutée dans `app_router.dart` — 2026-08-29
- [x] Flèches retour obsolètes dans `catalogue_screen.dart` et `gestion_users_screen.dart` (pointaient vers l'ancien dashboard à boutons empilés) : masquées quand ces écrans sont utilisés comme onglet (`embeddedInShell: true`), conservées pour leur usage historique en route poussée — 2026-08-29
- [x] Bouton retour de `creer_utilisateur_screen.dart` pointait vers la route autonome `/admin/users` (sans bottom navigation) : redirigé vers `/admin/dashboard` — 2026-08-29

---

## État final de la refonte (2026-08-29)

Toutes les migrations SQL sont exécutées, l'Edge Function est déployée, et les 4 fonctionnalités qui en dépendaient ont été testées en conditions réelles avec succès : upload de note de cours, upload d'image de formation, enregistrement d'un paiement manuel (avec recalcul correct du solde), et restriction d'accès automatique quand un apprenant est marqué "bloqué". `flutter analyze` et `flutter build web` passent sans erreur.

**Il ne reste plus qu'une seule chose, hors périmètre technique** : l'intégration Mobile Money réelle (Fedapay ou KKiaPay) derrière le bouton "Payer maintenant" côté apprenant — l'UI est prête et attend la clé API du fournisseur que tu choisiras.

### Pièges rencontrés pendant cette dernière série de tests (à ne pas réintroduire)
- **Edge Functions Supabase** : importer `@supabase/supabase-js` via `https://esm.sh/...` peut faire planter la fonction au démarrage sur le runtime Deno (symptôme : `401 Invalid credentials` identique quel que soit le token, logs montrant `reason: EarlyDrop`). Utiliser `jsr:@supabase/supabase-js@2` à la place.
- **file_picker sur le web** : après toute mise à jour de version majeure de ce package (ou de tout plugin natif), lancer `flutter clean` avant de rebuilder — sinon `UnimplementedError`/`LateInitializationError` au premier appel, la génération des plugins web restant périmée (même piège que `shared_preferences`, déjà documenté section 7).