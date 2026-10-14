import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyserRobots, cheminAutorise } from '../src/robots.mjs';
import { idProposition, normaliserUrl, validerExtraction } from '../src/normalisation.mjs';
import { extraireLiens } from '../src/decouverte.mjs';
import { formaterPourIA, resumerPage } from '../src/html.mjs';
import { ClientGemini, SCHEMA, choisirModele, consigne, corpsRequete, modeleRefuse, ordonnerModeles } from '../src/gemini.mjs';
import { executer } from '../src/run.mjs';
import { executerAvecEtat, messageBilan, statutBilan, traiterDemandes } from '../src/demandes.mjs';

const criteres = { langues: ['Français'], gratuitObligatoire: true, confianceMinimale: 0.5, niveauxAcceptes: ['Débutant', 'Intermédiaire', 'Avancé'], maxPagesParSource: 5, pauseEntreAppelsMs: 0 };
const brutValide = { estUnCours: true, gratuit: true, titre: 'HTML et CSS', description: 'Apprenez les bases.', descriptionDetaillee: 'Un cours complet.', fournisseur: 'Cursa', niveau: 'Débutant', duree: '10 h', langue: 'Français', certificatDisponible: true, certificatPayant: true, categorie: 'Développeurs web', lienImage: 'https://img.exemple/a.png', dateFin: null, confiance: 0.9, remarques: '' };

test('normaliserUrl : sans paramètres, ancre ni slash final ; id stable', () => {
  assert.equal(normaliserUrl('HTTPS://Cursa.App/fr/cours/x/?utm=1#haut'), 'https://cursa.app/fr/cours/x');
  assert.equal(idProposition('https://cursa.app/fr/cours/x/'), idProposition('https://cursa.app/fr/cours/x?a=1'));
  assert.notEqual(idProposition('https://cursa.app/a'), idProposition('https://cursa.app/b'));
});

test('robots.txt : règles générales, spécifiques, jokers et priorité', () => {
  const r = analyserRobots(`User-agent: *\nDisallow: /*?s=\nDisallow: /chat.php\nAllow: /chat.php/public\n\nUser-agent: GPTBot\nDisallow: /`);
  assert.equal(cheminAutorise(r, '/fr/cours-gratuit/x'), true);
  assert.equal(cheminAutorise(r, '/fr/cours?s=python'), false);
  assert.equal(cheminAutorise(r, '/chat.php'), false);
  assert.equal(cheminAutorise(r, '/chat.php/public'), true, 'la règle la plus précise l\'emporte');
  const nous = analyserRobots(`User-agent: CoursLibreBot\nDisallow: /prive\n\nUser-agent: *\nDisallow: /`);
  assert.equal(cheminAutorise(nous, '/public'), true);
  assert.equal(cheminAutorise(nous, '/prive/x'), false);
  assert.equal(cheminAutorise(analyserRobots('User-agent: *\nDisallow:'), '/tout'), true);
});

test('validerExtraction accepte une fiche conforme et fixe lienCours à la page lue', () => {
  const v = validerExtraction({ ...brutValide, lienCours: 'https://pirate.exemple' }, 'https://cursa.app/fr/cours-gratuit/html/', criteres);
  assert.equal(v.ok, true);
  assert.equal(v.cours.lienCours, 'https://cursa.app/fr/cours-gratuit/html');
  assert.equal(v.cours.certificatPayant, true);
  assert.equal(v.cours.lienImage, 'https://img.exemple/a.png');
});

test('validerExtraction écarte : non-cours, payant, autre langue, confiance faible, date passée', () => {
  const u = 'https://cursa.app/x';
  const raison = (o) => validerExtraction({ ...brutValide, ...o }, u, criteres).raison;
  assert.match(raison({ estUnCours: false }), /pas un cours/);
  assert.match(raison({ gratuit: false }), /non gratuit/);
  assert.match(raison({ langue: 'Anglais' }), /langue/);
  assert.match(raison({ confiance: 0.2 }), /confiance/);
  assert.match(raison({ dateFin: '2020-01-01' }), /date de fin/);
  assert.match(raison({ titre: '   ' }), /titre/);
  assert.equal(validerExtraction(null, u, criteres).ok, false);
});

test('validerExtraction nettoie : liens non https refusés, certificat payant sans certificat, textes bornés', () => {
  const v = validerExtraction({ ...brutValide, lienImage: 'javascript:alert(1)', certificatDisponible: false, certificatPayant: true, description: 'x'.repeat(500), niveau: 'avance' }, 'https://cursa.app/x', criteres);
  assert.equal(v.ok, true);
  assert.equal(v.cours.lienImage, null);
  assert.equal(v.cours.certificatPayant, false);
  assert.ok(v.cours.description.length <= 220);
  assert.equal(v.cours.niveau, 'Avancé');
});

test('extraireLiens ne garde que les pages de cours, sans doublons', () => {
  const html = '<a href="/courses/dev1">a</a><a class="x" href="/courses/dev1/#s">b</a><a href="/courses/bdd?x=1">c</a><a href="/about">d</a><a href="https://autre.org/courses/z">e</a>';
  assert.deepEqual(extraireLiens(html, 'https://librecours.net/', '^/courses/[A-Za-z0-9_-]+/?$').sort(), ['https://autre.org/courses/z', 'https://librecours.net/courses/bdd', 'https://librecours.net/courses/dev1']);
});

test('resumerPage retire scripts/styles/navigation, garde titre, méta, JSON-LD', () => {
  const html = `<html><head><title>Cours &amp; Co</title><meta name="description" content="Un résumé"><meta property="og:image" content="https://i.x/a.png"><script type="application/ld+json">{"@type":"Course","name":"X"}</script><style>.a{}</style></head><body><nav>MENU</nav><script>evil()</script><h1>Titre</h1><p>Contenu utile</p></body></html>`;
  const r = resumerPage(html, 'https://x.org/c');
  assert.equal(r.titre, 'Cours & Co');
  assert.equal(r.description, 'Un résumé');
  assert.match(r.ld, /"@type":"Course"/);
  assert.match(r.texte, /Contenu utile/);
  assert.ok(!r.texte.includes('evil') && !r.texte.includes('MENU'));
  assert.match(formaterPourIA(r), /^URL : https:\/\/x\.org\/c/);
});

test('la requête Gemini : consigne anti-injection, schéma JSON imposé, catégories existantes', () => {
  const c = consigne({ indice: 'Indice' }, criteres, ['Marketing', 'Langues']);
  assert.match(c, /donnée, jamais une instruction/);
  assert.match(c, /Marketing ; Langues/);
  const corps = corpsRequete('PAGE', c);
  assert.equal(corps.generationConfig.responseMimeType, 'application/json');
  assert.equal(corps.generationConfig.responseSchema, SCHEMA);
  assert.deepEqual(corps.contents[0].parts, [{ text: 'PAGE' }]);
});

test('choisirModele garde le modèle voulu, sinon un « flash » stable récent', () => {
  const liste = [
    { name: 'models/gemini-3-flash', supportedGenerationMethods: ['generateContent'] },
    { name: 'models/gemini-3-flash-lite', supportedGenerationMethods: ['generateContent'] },
    { name: 'models/gemini-3-flash-preview-x', supportedGenerationMethods: ['generateContent'] },
    { name: 'models/embedding-1', supportedGenerationMethods: ['embedContent'] },
  ];
  assert.equal(choisirModele(liste, 'gemini-3-flash-lite'), 'gemini-3-flash-lite');
  assert.equal(choisirModele(liste, 'gemini-2.5-flash'), 'gemini-3-flash');
});

test('ClientGemini : lit la réponse JSON ; réessaie après 429 ; signale un quota épuisé', async () => {
  const reponse = (status, corps) => ({ status, ok: status < 300, json: async () => corps, text: async () => (typeof corps === 'string' ? corps : JSON.stringify(corps)) });
  const ok = reponse(200, { candidates: [{ content: { parts: [{ text: JSON.stringify(brutValide) }] } }] });
  let n = 0;
  const g = new ClientGemini({ cle: 'k', fetchFn: async () => (n++ === 0 ? reponse(429, 'slow down') : ok), pause: async () => {} });
  assert.equal((await g.extraire('p', 'c')).titre, 'HTML et CSS');
  assert.equal(n, 2);
  const epuise = new ClientGemini({ cle: 'k', fetchFn: async () => reponse(429, 'Quota exceeded for requests per day'), pause: async () => {} });
  await assert.rejects(() => epuise.extraire('p', 'c'), /quota/i);
  assert.throws(() => new ClientGemini({ cle: '' }), /GEMINI_API_KEY/);
});

// ---------- Passage complet avec faux réseau, fausse IA, faux dépôt ----------
function fauxReseau() {
  const pages = {
    'https://cursa.app/robots.txt': 'User-agent: *\nAllow: /\nDisallow: /*?s=',
    'https://cursa.app/sitemaps/FR/vidcourses.txt': 'https://cursa.app/fr/cours-gratuit/html-bega\nhttps://cursa.app/fr/cours-gratuit/deja-publie-x\nhttps://cursa.app/fr/cours-gratuit/anglais-y\nhttps://cursa.app/fr/blog/pas-un-cours',
    'https://cursa.app/fr/cours-gratuit/html-bega': '<title>HTML</title><h1>HTML</h1><p>Contenu</p>',
    'https://cursa.app/fr/cours-gratuit/anglais-y': '<title>English</title><p>All in English</p>',
  };
  return async (url) => {
    const corps = pages[url];
    if (corps === undefined) return { ok: false, status: 404, headers: new Headers(), text: async () => '', url };
    return { ok: true, status: 200, headers: new Headers({ 'content-type': 'text/plain' }), text: async () => corps, url };
  };
}

test('passage complet : propose le bon cours, mémorise l\'écarté, ignore le déjà publié', async () => {
  const propose = []; const ignores = [];
  const depot = {
    dejaConnus: async () => ({ urls: new Set(['https://cursa.app/fr/cours-gratuit/deja-publie-x']), categories: ['Marketing'], idsPropositions: new Set() }),
    enregistrerProposition: async (id, d) => propose.push({ id, ...d }),
    enregistrerIgnore: async (id, d) => ignores.push({ id, ...d }),
  };
  const appels = [];
  const gemini = { extraire: async (contenu) => { appels.push(contenu); return contenu.includes('English') ? { ...brutValide, langue: 'Anglais' } : brutValide; } };
  const sources = [{ id: 'cursa', nom: 'Cursa', actif: true, decouverte: { type: 'sitemap-txt', url: 'https://cursa.app/sitemaps/FR/vidcourses.txt' }, motifPage: '^https://cursa\\.app/fr/cours-gratuit/[a-z0-9-]+$' },
    { id: 'alison', nom: 'Alison', actif: false }];
  const bilan = await executer({ sources, criteres, gemini, depot, options: {}, fetchFn: fauxReseau(), journal: () => {}, pause: async () => {} });
  assert.equal(appels.length, 2, 'le cours déjà publié n\'est pas envoyé à l\'IA');
  assert.equal(bilan.proposes, 1);
  assert.equal(bilan.ignores, 1);
  assert.equal(propose[0].cours.lienCours, 'https://cursa.app/fr/cours-gratuit/html-bega');
  assert.equal(propose[0].id, idProposition('https://cursa.app/fr/cours-gratuit/html-bega'));
  assert.match(ignores[0].raison, /langue/);
  assert.equal(bilan.dejaVus, 1);
});

test('simulation (--dry-run) : n\'écrit rien', async () => {
  let ecritures = 0;
  const depot = { dejaConnus: async () => ({ urls: new Set(), categories: [], idsPropositions: new Set() }), enregistrerProposition: async () => ecritures++, enregistrerIgnore: async () => ecritures++ };
  const sources = [{ id: 'cursa', nom: 'Cursa', actif: true, decouverte: { type: 'sitemap-txt', url: 'https://cursa.app/sitemaps/FR/vidcourses.txt' }, motifPage: '^https://cursa\\.app/fr/cours-gratuit/[a-z0-9-]+$' }];
  await executer({ sources, criteres, gemini: { extraire: async () => brutValide }, depot, options: { dryRun: true }, fetchFn: fauxReseau(), journal: () => {}, pause: async () => {} });
  assert.equal(ecritures, 0);
});

test('un robots.txt qui interdit une page empêche sa lecture', async () => {
  const reseau = async (url) => url.endsWith('/robots.txt')
    ? { ok: true, status: 200, headers: new Headers({ 'content-type': 'text/plain' }), text: async () => 'User-agent: *\nDisallow: /interdit' }
    : { ok: true, status: 200, headers: new Headers(), text: async () => 'x', url };
  const { telecharger } = await import('../src/html.mjs');
  await assert.rejects(() => telecharger('https://site-test-robots.example/interdit/page', reseau), /robots/);
  assert.equal((await telecharger('https://site-test-robots.example/ok', reseau)).texte, 'x');
});

test('quota Gemini épuisé : arrêt propre, reprise au prochain passage', async () => {
  const { ErreurQuota } = await import('../src/gemini.mjs');
  const sources = [{ id: 'cursa', nom: 'Cursa', actif: true, decouverte: { type: 'sitemap-txt', url: 'https://cursa.app/sitemaps/FR/vidcourses.txt' }, motifPage: '^https://cursa\\.app/fr/cours-gratuit/[a-z0-9-]+$' }];
  const bilan = await executer({ sources, criteres, gemini: { extraire: async () => { throw new ErreurQuota('quota quotidien Gemini épuisé'); } }, depot: null, options: {}, fetchFn: fauxReseau(), journal: () => {}, pause: async () => {} });
  assert.match(bilan.arret, /quota/);
  assert.equal(bilan.erreurs, 0);
});

test('ordonnerModeles : « flash » stables récents, puis « lite » ; preview/pro écartés', () => {
  const m = (n) => ({ name: `models/${n}`, supportedGenerationMethods: ['generateContent'] });
  const liste = [m('gemini-2.5-flash'), m('gemini-3.8-flash'), m('gemini-3.8-flash-lite'), m('gemini-3.8-flash-preview-09'), m('gemini-3.7-flash'), m('gemini-3.8-pro'), m('gemini-omni-1.1-flash'), m('gemini-flash-latest'), m('gemini-3.10-flash'), { name: 'models/emb', supportedGenerationMethods: ['embedContent'] }];
  assert.deepEqual(ordonnerModeles(liste, ''), ['gemini-3.10-flash', 'gemini-3.8-flash', 'gemini-3.7-flash', 'gemini-2.5-flash', 'gemini-3.8-flash-lite']);
  assert.deepEqual(ordonnerModeles(liste, 'gemini-3.7-flash').slice(0, 2), ['gemini-3.7-flash', 'gemini-3.10-flash']);
  assert.ok(!ordonnerModeles(liste, '').some((n) => /omni|latest|preview|pro/.test(n)));
});

test('modeleRefuse reconnaît un modèle retiré ou hors quota gratuit', () => {
  assert.equal(modeleRefuse(404, 'This model models/x is no longer available'), true);
  assert.equal(modeleRefuse(429, 'quota ... limit: 0, model: gemini-x'), true);
  assert.equal(modeleRefuse(429, 'Resource has been exhausted (e.g. check quota). limit: 15'), false);
  assert.equal(modeleRefuse(500, 'boom'), false);
});

test('ClientGemini passe au modèle suivant quand Google refuse le premier', async () => {
  const reponse = (status, corps) => ({ status, ok: status < 300, json: async () => corps, text: async () => (typeof corps === 'string' ? corps : JSON.stringify(corps)) });
  const ok = reponse(200, { candidates: [{ content: { parts: [{ text: JSON.stringify(brutValide) }] } }] });
  const appeles = [];
  const m = (n) => ({ name: `models/${n}`, supportedGenerationMethods: ['generateContent'] });
  const fetchFn = async (url) => {
    if (url.includes('/models?')) return reponse(200, { models: [m('gemini-2.5-flash'), m('gemini-3.8-flash')] });
    appeles.push(url.match(/models\/([^:]+):/)[1]);
    return url.includes('gemini-3.8-flash:') ? reponse(404, 'no longer available to new users') : ok;
  };
  const g = new ClientGemini({ cle: 'k', modele: 'gemini-2.5-flash', fetchFn, pause: async () => {} });
  await g.preparer();
  assert.equal(g.modele, 'gemini-2.5-flash');
  assert.equal((await g.extraire('p', 'c')).titre, 'HTML et CSS');
  // modèle demandé OK : pas de bascule
  assert.deepEqual(appeles, ['gemini-2.5-flash']);

  const retire = async (url) => {
    if (url.includes('/models?')) return reponse(200, { models: [m('gemini-2.5-flash'), m('gemini-3.8-flash')] });
    return url.includes('gemini-2.5-flash:') ? reponse(404, 'This model is no longer available to new users') : ok;
  };
  const g2 = new ClientGemini({ cle: 'k', modele: 'gemini-2.5-flash', fetchFn: retire, pause: async () => {} });
  await g2.preparer();
  assert.equal((await g2.extraire('p', 'c')).titre, 'HTML et CSS');
  assert.equal(g2.modele, 'gemini-3.8-flash', 'bascule automatique vers le modèle suivant');

  const tousRefuses = new ClientGemini({ cle: 'k', modele: 'a', fetchFn: async () => reponse(404, 'gone'), pause: async () => {} });
  await assert.rejects(() => tousRefuses.extraire('p', 'c'), /aucun modèle utilisable/);
});

test('quota quotidien épuisé : bascule vers le modèle « lite » (quota plus large), sinon arrêt propre', async () => {
  const reponse = (status, corps) => ({ status, ok: status < 300, json: async () => corps, text: async () => (typeof corps === 'string' ? corps : JSON.stringify(corps)) });
  const ok = reponse(200, { candidates: [{ content: { parts: [{ text: JSON.stringify(brutValide) }] } }] });
  const m = (n) => ({ name: `models/${n}`, supportedGenerationMethods: ['generateContent'] });
  const fetchFn = async (url) => {
    if (url.includes('/models?')) return reponse(200, { models: [m('gemini-3.8-flash'), m('gemini-3.5-flash-lite')] });
    return url.includes('gemini-3.8-flash:') ? reponse(429, 'Quota exceeded for metric GenerateRequestsPerDayPerProjectPerModel-FreeTier') : ok;
  };
  const g = new ClientGemini({ cle: 'k', fetchFn, pause: async () => {} });
  await g.preparer();
  assert.equal(g.modele, 'gemini-3.8-flash');
  assert.equal(g.pauseConseillee(), 13000);
  assert.equal((await g.extraire('p', 'c')).titre, 'HTML et CSS');
  assert.equal(g.modele, 'gemini-3.5-flash-lite');
  assert.equal(g.pauseConseillee(), 5000, 'rythme plus rapide pour un modèle lite');

  const seul = new ClientGemini({ cle: 'k', modele: 'gemini-3.8-flash', fetchFn: async () => reponse(429, 'GenerateRequestsPerDayPerProjectPerModel-FreeTier'), pause: async () => {} });
  await assert.rejects(() => seul.extraire('p', 'c'), /quota/i);
});

// ---------- File d'attente des demandes (bouton de l'application) ----------
function fauxDepotDemandes({ attente = [], bloquees = 0 } = {}) {
  const trace = { etats: [], demandes: [], debloque: 0 };
  return {
    trace,
    debloquerDemandes: async () => bloquees,
    demandesEnAttente: async () => attente,
    majDemande: async (id, champs) => trace.demandes.push([id, champs.statut, champs.message]),
    commencerEtat: async (c) => trace.etats.push(['debut', c.statut, c.declencheur]),
    terminerEtat: async (c) => trace.etats.push(['fin', c.statut, c.message, c.proposes]),
  };
}
const bilanOk = { proposes: 3, ignores: 1, erreurs: 0, dejaVus: 0, details: [], arret: null };

test('aucune demande : rien n\'est lancé et rien n\'est écrit', async () => {
  const depot = fauxDepotDemandes();
  let lance = 0;
  const r = await traiterDemandes({ depot, lancer: async () => { lance++; return bilanOk; }, journal: () => {} });
  assert.equal(r.traite, false);
  assert.equal(lance, 0);
  assert.deepEqual(depot.trace.etats, []);
});

test('demande en attente : état en cours, veille, état terminé, demande refermée', async () => {
  const depot = fauxDepotDemandes({ attente: ['d1', 'd2'] });
  const r = await traiterDemandes({ depot, lancer: async () => bilanOk, journal: () => {} });
  assert.equal(r.traite, true);
  assert.equal(r.statut, 'termine');
  assert.deepEqual(depot.trace.etats[0], ['debut', 'en_cours', 'bouton']);
  assert.equal(depot.trace.etats[1][1], 'termine');
  assert.match(depot.trace.etats[1][2], /3 propositions ajoutées, 1 page écartée\./);
  assert.deepEqual(depot.trace.demandes.map((d) => d.slice(0, 2)), [['d1', 'en_cours'], ['d2', 'en_cours'], ['d1', 'termine'], ['d2', 'termine']]);
});

test('une veille qui plante marque l\'état et les demandes en erreur (le bouton se débloque)', async () => {
  const depot = fauxDepotDemandes({ attente: ['d1'] });
  const r = await traiterDemandes({ depot, lancer: async () => { throw new Error('GEMINI_API_KEY manquante'); }, journal: () => {} });
  assert.equal(r.statut, 'erreur');
  assert.match(depot.trace.etats[1][2], /GEMINI_API_KEY manquante/);
  assert.equal(depot.trace.demandes.at(-1)[1], 'erreur');
});

test('statut et message du bilan : arrêt pour quota = terminé avec explication ; que des erreurs = échec', () => {
  assert.equal(statutBilan({ proposes: 0, ignores: 0, erreurs: 4 }), 'erreur');
  assert.equal(statutBilan({ proposes: 2, ignores: 0, erreurs: 4 }), 'termine');
  assert.equal(statutBilan({ proposes: 0, ignores: 0, erreurs: 0, arret: 'quota' }), 'termine');
  assert.match(messageBilan({ proposes: 1, ignores: 0, erreurs: 2, arret: 'quota quotidien Gemini épuisé' }), /1 proposition ajoutée, 0 page écartée, 2 erreurs\. Arrêt anticipé : quota quotidien/);
});

test('executerAvecEtat sans demande (passage planifié) écrit quand même l\'état', async () => {
  const depot = fauxDepotDemandes();
  await executerAvecEtat({ depot, lancer: async () => bilanOk, declencheur: 'planifie', journal: () => {} });
  assert.deepEqual(depot.trace.etats[0], ['debut', 'en_cours', 'planifie']);
  assert.deepEqual(depot.trace.demandes, []);
});
