# Veille automatique de cours

Programme qui cherche des cours gratuits sur des sites choisis, les fait lire
par **Gemini**, et dépose des **propositions** dans Firestore
(`cours_propositions`). Le super-admin les valide dans l'application
(*Espace super-admin → Propositions de cours*) : **rien n'est publié sans
validation**.

## Déroulement d'un passage
1. Pour chaque source active de `sources.json` : découverte des adresses de cours
   (plan du site ou liens d'une page).
2. On écarte les cours déjà publiés et les pages déjà traitées (y compris
   celles écartées : elles ne consomment plus de quota).
3. Pour chaque nouvelle page (max `maxPagesParSource`) : lecture de la page
   (en respectant `robots.txt`), réduction en texte court, extraction par Gemini
   selon un schéma JSON imposé (les champs de la fiche d'ajout d'un cours).
4. Contrôle des critères (`criteres.json`) : cours unique, gratuit, langue,
   niveau, confiance minimale, date de fin non passée, liens en https.
5. Enregistrement : proposition `a_valider`, ou page `ignore` (avec la raison).

L'adresse du cours est toujours celle de la page lue : l'IA ne l'invente jamais.
Le texte des pages est traité comme une donnée (consigne anti-injection).

## Configuration
- `sources.json` : sites, type de découverte, motif des pages de cours, indices pour l'IA.
  Mettre `"actif": true` pour activer une source.
- `criteres.json` : langues acceptées, gratuité obligatoire, confiance minimale,
  nombre de pages par source et par passage, pause entre appels (quota gratuit Gemini).

## Utilisation
- **Depuis l'application** : *Espace super-admin → Propositions de cours → Lancer la
  veille maintenant*. L'application dépose une demande (`veille_demandes`) ; la
  tâche **Veille - demandes de l'application** (toutes les ~10 min) la lit et
  lance la veille. L'état (en attente / en cours / terminé / échec) s'affiche en
  direct dans l'application (`veille_etat/courant`). Délai de démarrage : jusqu'à
  10-15 min (GitHub retarde parfois ses tâches planifiées).
- **Chaque lundi** : tâche **Veille de cours** (GitHub Actions).
- **À la main** : onglet **Actions → Veille de cours → Run workflow** (case
  « simulation » pour ne rien écrire, champs `source` et `pages`).

Les tâches planifiées d'un dépôt sans aucune activité pendant 60 jours sont
désactivées par GitHub : un simple commit les réactive.

En local :
```bash
cd veille && npm install
GEMINI_API_KEY=... node src/run.mjs --dry-run --source=cursa --max=2
npm test
```
Écriture réelle : ajouter `FIREBASE_SERVICE_ACCOUNT` (JSON du compte de service).

## Mise en place (une fois)
```bash
# 1. Clé Gemini : https://aistudio.google.com/apikey
gh secret set GEMINI_API_KEY --repo taoficadebissi-eng/Gestion-formation-CL

# 2. Compte de service : console Firebase > Paramètres du projet > Comptes de
#    service > « Générer une nouvelle clé privée » (télécharge un fichier .json)
gh secret set FIREBASE_SERVICE_ACCOUNT --repo taoficadebissi-eng/Gestion-formation-CL < chemin/vers/cle.json
rm chemin/vers/cle.json   # ne jamais la garder dans le projet
```

## Sources
| Source | Statut | Remarque |
|---|---|---|
| Cursa | actif | plan du site FR : ~370 cours |
| LibreCours | actif | 22 cours, page d'accueil |
| Alison | étape 2 | plan du site en anglais/espagnol seulement |
| OpenClassrooms | étape 2 | liste chargée en JavaScript, pas de plan du site |

Avant d'activer un site, vérifier ses conditions d'utilisation : certains
interdisent l'extraction automatique, même quand `robots.txt` l'autorise.
