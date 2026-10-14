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

export async function decouvrir(source, fetchFn = fetch) {
  const { type, url, motifLien } = source.decouverte;
  const { texte } = await telecharger(url, fetchFn);
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
