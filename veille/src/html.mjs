// Récupération d'une page et réduction en un texte court pour l'IA.
import { robotsAutorise } from './robots.mjs';

export const USER_AGENT = 'CoursLibreBot/1.0 (+https://courslibre-gf.web.app; veille de cours gratuits)';
const TAILLE_MAX = 2 * 1024 * 1024;

export async function telecharger(url, fetchFn = fetch) {
  if (!(await robotsAutorise(url, fetchFn))) throw new Error('interdit par robots.txt');
  const reponse = await fetchFn(url, {
    headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,text/plain', 'Accept-Language': 'fr' },
    redirect: 'follow',
    signal: AbortSignal.timeout(25000),
  });
  if (!reponse.ok) throw new Error(`HTTP ${reponse.status}`);
  const texte = await reponse.text();
  if (texte.length > TAILLE_MAX) throw new Error('page trop volumineuse');
  return { texte, urlFinale: reponse.url || url };
}

const ENTITES = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'", '&nbsp;': ' ', '&laquo;': '«', '&raquo;': '»' };
export function decoder(texte) {
  return texte
    .replace(/&(amp|lt|gt|quot|apos|nbsp|laquo|raquo|#39);/g, (m) => ENTITES[m] ?? m)
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)));
}

function meta(html, cle) {
  const motif = new RegExp(`<meta[^>]+(?:name|property)=["']${cle}["'][^>]*>`, 'i');
  const balise = html.match(motif)?.[0];
  const contenu = balise?.match(/content=["']([^"']*)["']/i)?.[1];
  return contenu ? decoder(contenu).trim() : '';
}

/** Extrait titre, métadonnées, JSON-LD et texte visible, avec une taille bornée. */
export function resumerPage(html, urlPage, { maxTexte = 9000, maxLd = 3500 } = {}) {
  const titre = decoder(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? '').replace(/\s+/g, ' ').trim();
  const description = meta(html, 'description') || meta(html, 'og:description');
  const image = meta(html, 'og:image');
  const ld = [...html.matchAll(/<script[^>]+application\/ld\+json[^>]*>([\s\S]*?)<\/script>/gi)]
    .map((m) => m[1].trim().replace(/\s+/g, ' '))
    .join('\n')
    .slice(0, maxLd);
  const texte = decoder(
    html
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<(script|style|noscript|svg|nav|footer|header|form|iframe)[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<(br|\/p|\/div|\/li|\/h[1-6]|\/tr)[^>]*>/gi, '\n')
      .replace(/<[^>]+>/g, ' '),
  )
    .replace(/[ \t\f\v ]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .replace(/\n{2,}/g, '\n')
    .trim()
    .slice(0, maxTexte);
  return { url: urlPage, titre, description, image, ld, texte };
}

export function formaterPourIA(r) {
  return [
    `URL : ${r.url}`,
    `TITRE : ${r.titre}`,
    r.description ? `DESCRIPTION META : ${r.description}` : '',
    r.image ? `IMAGE OG : ${r.image}` : '',
    r.ld ? `DONNEES STRUCTUREES (JSON-LD) : ${r.ld}` : '',
    `TEXTE DE LA PAGE :\n${r.texte}`,
  ].filter(Boolean).join('\n');
}
