// Respect de robots.txt : on ne lit jamais une page qu'un site interdit.
const AGENT = 'courslibrebot';
const cache = new Map();

function versRegex(modele) {
  const fin = modele.endsWith('$');
  const corps = (fin ? modele.slice(0, -1) : modele)
    .replace(/[.+?^${}()|[\]\\]/g, '\\$&')
    .replace(/\*/g, '.*');
  return new RegExp('^' + corps + (fin ? '$' : ''));
}

/** Analyse un robots.txt ; retourne la liste des règles qui nous concernent. */
export function analyserRobots(texte) {
  let groupes = [];
  let enRegles = false;
  const nous = { specifique: [], general: [] };
  let courant = null;
  for (const brute of texte.split(/\r?\n/)) {
    const ligne = brute.replace(/#.*/, '').trim();
    if (!ligne) continue;
    const i = ligne.indexOf(':');
    if (i < 0) continue;
    const cle = ligne.slice(0, i).trim().toLowerCase();
    const valeur = ligne.slice(i + 1).trim();
    if (cle === 'user-agent') {
      if (enRegles) { groupes = []; enRegles = false; }
      groupes.push(valeur.toLowerCase());
      courant = groupes;
    } else if ((cle === 'allow' || cle === 'disallow') && courant) {
      enRegles = true;
      const regle = { autorise: cle === 'allow', motif: valeur };
      if (groupes.some((g) => g !== '*' && AGENT.includes(g))) nous.specifique.push(regle);
      else if (groupes.includes('*')) nous.general.push(regle);
    }
  }
  return nous.specifique.length ? nous.specifique : nous.general;
}

export function cheminAutorise(regles, chemin) {
  let meilleure = null;
  for (const r of regles) {
    if (!r.motif) continue; // « Disallow: » vide = tout autorisé
    if (!versRegex(r.motif).test(chemin)) continue;
    if (!meilleure || r.motif.length > meilleure.motif.length || (r.motif.length === meilleure.motif.length && r.autorise)) {
      meilleure = r;
    }
  }
  return meilleure ? meilleure.autorise : true;
}

export async function robotsAutorise(url, fetchFn = fetch, userAgent = 'CoursLibreBot/1.0') {
  const u = new URL(url);
  if (!cache.has(u.origin)) {
    let regles = [];
    try {
      const r = await fetchFn(`${u.origin}/robots.txt`, { headers: { 'User-Agent': userAgent }, signal: AbortSignal.timeout(15000) });
      const type = r.headers?.get?.('content-type') ?? '';
      if (r.ok && !type.includes('html')) regles = analyserRobots(await r.text());
    } catch { /* robots illisible : on reste prudent mais on n'invente pas d'interdiction */ }
    cache.set(u.origin, regles);
  }
  return cheminAutorise(cache.get(u.origin), u.pathname + u.search);
}
