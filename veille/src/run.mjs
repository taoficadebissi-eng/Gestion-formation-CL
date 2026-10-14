// Veille automatique : découvre des cours sur les sites configurés, les fait
// lire par Gemini, et dépose des PROPOSITIONS que le super-admin valide dans
// l'application. Rien n'est publié sans validation.
//
//   node src/run.mjs                 passage normal
//   node src/run.mjs --dry-run       n'écrit rien, affiche ce qui serait proposé
//   node src/run.mjs --source=cursa  une seule source
//   node src/run.mjs --max=3         au plus 3 pages par source
import dns from 'node:dns';
import net from 'node:net';
import { appendFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { decouvrir } from './decouverte.mjs';
import { executerAvecEtat, traiterDemandes } from './demandes.mjs';
import { ClientGemini, ErreurQuota, consigne } from './gemini.mjs';
import { formaterPourIA, resumerPage, telecharger } from './html.mjs';
import { idProposition, normaliserUrl, validerExtraction } from './normalisation.mjs';

dns.setDefaultResultOrder('ipv4first');
net.setDefaultAutoSelectFamilyAttemptTimeout?.(2000);

const racine = join(dirname(fileURLToPath(import.meta.url)), '..');
const lire = (nom) => JSON.parse(readFileSync(join(racine, nom), 'utf8'));

export async function executer({ sources, criteres, gemini, depot, options, fetchFn = fetch, journal = console.log, pause = (ms) => new Promise((r) => setTimeout(r, ms)) }) {
  const bilan = { proposes: 0, ignores: 0, erreurs: 0, dejaVus: 0, details: [], arret: null };
  let connus = { urls: new Set(), categories: [], idsPropositions: new Set() };
  if (depot) connus = await depot.dejaConnus();
  journal(`${connus.urls.size} cours déjà publiés, ${connus.idsPropositions.size} pages déjà traitées.`);

  const maxPages = options.max ?? criteres.maxPagesParSource;
  for (const source of sources) {
    if (options.source && source.id !== options.source) continue;
    if (!source.actif) { journal(`[${source.nom}] désactivée${source.note ? ` — ${source.note}` : ''}`); continue; }

    let urls;
    try {
      urls = await decouvrir(source, fetchFn);
    } catch (e) {
      journal(`[${source.nom}] découverte impossible : ${e.message}`);
      bilan.erreurs++;
      continue;
    }
    const nouvelles = urls.filter((u) => !connus.urls.has(u) && !connus.idsPropositions.has(idProposition(u)));
    bilan.dejaVus += urls.length - nouvelles.length;
    journal(`[${source.nom}] ${urls.length} cours trouvés, ${nouvelles.length} nouveaux ; analyse de ${Math.min(maxPages, nouvelles.length)}.`);

    for (const url of nouvelles.slice(0, maxPages)) {
      const id = idProposition(url);
      try {
        const { texte, urlFinale } = await telecharger(url, fetchFn);
        // Redirigée vers une autre page (connexion exigée, cours retiré...) :
        // inutile de dépenser une requête Gemini dessus.
        if (!new RegExp(source.motifPage).test(normaliserUrl(urlFinale))) {
          const raison = 'page redirigée (accès restreint ou cours retiré)';
          if (depot && !options.dryRun) await depot.enregistrerIgnore(id, { url, raison, source });
          bilan.ignores++;
          journal(`  - écarté : ${url} (${raison})`);
          continue;
        }
        const page = resumerPage(texte, urlFinale);
        const brut = await gemini.extraire(formaterPourIA(page), consigne(source, criteres, connus.categories));
        const verdict = validerExtraction(brut, url, criteres);
        if (verdict.ok) {
          if (depot && !options.dryRun) await depot.enregistrerProposition(id, { ...verdict, source });
          bilan.proposes++;
          bilan.details.push(`+ ${verdict.cours.titre} (${verdict.cours.fournisseur}, confiance ${verdict.confiance})`);
          journal(`  + ${verdict.cours.titre}  [confiance ${verdict.confiance}]${verdict.remarques ? `  ⚠ ${verdict.remarques}` : ''}`);
          if (options.dryRun) journal(JSON.stringify({ ...verdict.cours, dateFin: verdict.cours.dateFin?.toISOString() ?? null }, null, 2));
        } else {
          if (depot && !options.dryRun) await depot.enregistrerIgnore(id, { url, raison: verdict.raison, source });
          bilan.ignores++;
          journal(`  - écarté : ${url} (${verdict.raison})`);
        }
      } catch (e) {
        if (e instanceof ErreurQuota) {
          bilan.arret = e.message;
          journal(`Arrêt : ${e.message}. Reprise au prochain passage.`);
          return bilan;
        }
        bilan.erreurs++;
        journal(`  ! erreur sur ${url} : ${e.message}`);
      }
      await pause(gemini.pauseConseillee?.() ?? criteres.pauseEntreAppelsMs ?? 7000);
    }
  }
  return bilan;
}

function resume(bilan, options) {
  const lignes = [
    `## Veille de cours${options.dryRun ? ' (simulation)' : ''}`,
    `- Propositions ajoutées : **${bilan.proposes}**`,
    `- Pages écartées : ${bilan.ignores}`,
    `- Erreurs : ${bilan.erreurs}`,
    `- Déjà connus : ${bilan.dejaVus}`,
    bilan.arret ? `- ⚠ Arrêt anticipé : ${bilan.arret}` : '',
    ...bilan.details.map((d) => `  - ${d}`),
  ].filter(Boolean).join('\n');
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, lignes + '\n');
  return lignes;
}

async function ouvrirDepot(options) {
  if (process.env.FIREBASE_SERVICE_ACCOUNT?.trim()) {
    const { DepotFirestore } = await import('./depot.mjs');
    const depot = new DepotFirestore(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log(`Base de données connectée (projet ${depot.projet}).`);
    return depot;
  }
  if (!options.dryRun) throw new Error('FIREBASE_SERVICE_ACCOUNT manquant ou vide (utilisez --dry-run pour essayer sans écrire).');
  console.log('⚠ Base de données NON connectée (FIREBASE_SERVICE_ACCOUNT manquant ou vide) : les cours déjà publiés ne seront pas détectés.');
  return null;
}

async function main() {
  const options = { dryRun: false, demandes: false };
  for (const a of process.argv.slice(2)) {
    if (a === '--dry-run') options.dryRun = true;
    else if (a === '--demandes') options.demandes = true;
    else if (a.startsWith('--source=')) options.source = a.slice(9);
    else if (a.startsWith('--max=')) options.max = Number(a.slice(6));
  }
  const depot = await ouvrirDepot(options);

  // Un passage complet : prépare Gemini, lit les sites, dépose les propositions.
  const lancer = async () => {
    const gemini = new ClientGemini({ cle: process.env.GEMINI_API_KEY, modele: process.env.GEMINI_MODEL || '' });
    await gemini.preparer();
    const bilan = await executer({ sources: lire('sources.json').sources, criteres: lire('criteres.json'), gemini, depot, options });
    console.log('\n' + resume(bilan, options));
    return bilan;
  };

  if (options.demandes) {
    await traiterDemandes({ depot, lancer });
    return;
  }
  if (depot && !options.dryRun) {
    const declencheur = process.env.GITHUB_EVENT_NAME === 'schedule' ? 'planifie' : 'manuel';
    const { statut } = await executerAvecEtat({ depot, lancer, declencheur });
    if (statut === 'erreur') process.exitCode = 1;
    return;
  }
  const bilan = await lancer();
  if (bilan.proposes === 0 && bilan.erreurs > 0 && bilan.ignores === 0) process.exitCode = 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => { console.error(`Échec : ${e.message}`); process.exit(1); });
}
