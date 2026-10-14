// Découverte des adresses de cours d'une source (plan du site ou liens d'une page).
import { normaliserUrl } from './normalisation.mjs';
import { telecharger } from './html.mjs';

export function extraireLiens(html, base, motifLien) {
  const re = new RegExp(motifLien);
  const trouves = new Set();
  for (const m of html.matchAll(/<a\s[^>]*href=["']([^"'#]+)[^"']*["']/gi)) {
    let u;
    try { u = new URL(m[1], base); } catch { continue; }
    if (re.test(u.pathname)) trouves.add(normaliserUrl(u.origin + u.pathname));
  }
  return [...trouves];
}

/**
 * API publique du CMS Richie (FUN MOOC) : liste paginée de cours. On ne garde
 * que ceux dont l'état contient l'un des `etatsAcceptes` (ex : « ouvert à
 * l'inscription »), pour ne pas proposer un cours déjà fermé.
 */
export async function decouvrirApiRichie(decouverte, fetchFn = fetch, maxCours = 800) {
  const { url, base, etatsAcceptes = [] } = decouverte;
  const acceptes = etatsAcceptes.map((e) => e.toLowerCase());
  const urls = [];
  for (let offset = 0; offset < maxCours; offset += 100) {
    const { texte } = await telecharger(`${url}?limit=100&offset=${offset}`, fetchFn, { accept: 'application/json' });
    const json = JSON.parse(texte);
    for (const c of json.objects ?? []) {
      const etat = String(c.state?.text ?? '').toLowerCase();
      if (c.absolute_url && (!acceptes.length || acceptes.some((a) => etat.includes(a)))) {
        urls.push(new URL(c.absolute_url, base).href);
      }
    }
    if (offset + 100 >= (json.meta?.total_count ?? 0)) break;
  }
  return urls;
}

export async function decouvrir(source, fetchFn = fetch) {
  const { type, url, motifLien } = source.decouverte;
  let urls;
  if (type === 'api-richie') {
    urls = await decouvrirApiRichie(source.decouverte, fetchFn);
  } else {
    urls = await decouvrirTexte(source, fetchFn, type, url, motifLien);
  }
  const motif = new RegExp(source.motifPage);
  const propres = new Set();
  for (const u of urls) {
    try {
      const n = normaliserUrl(u);
      if (motif.test(n)) propres.add(n);
    } catch { /* adresse invalide ignorée */ }
  }
  return [...propres];
}

async function decouvrirTexte(source, fetchFn, type, url, motifLien) {
  const estPlan = type === 'sitemap-txt' || type === 'sitemap-xml';
  const { texte } = await telecharger(url, fetchFn, estPlan ? { accept: '*/*', maxOctets: 40 * 1024 * 1024 } : {});
  let urls;
  if (type === 'sitemap-txt') {
    urls = texte.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.startsWith('https://'));
  } else if (type === 'sitemap-xml') {
    urls = [...texte.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/g)].map((m) => m[1]);
  } else if (type === 'liens') {
    urls = extraireLiens(texte, url, motifLien);
  } else {
    throw new Error(`type de découverte inconnu : ${type}`);
  }
  return urls;
}
