// Fonctions pures : normalisation d'adresses, contrôle et nettoyage de la
// réponse de l'IA. Aucune dépendance réseau : entièrement testables.
import { createHash } from 'node:crypto';

export const NIVEAUX = ['Débutant', 'Intermédiaire', 'Avancé'];

/** Adresse canonique : sans paramètres, sans ancre, sans « / » final. */
export function normaliserUrl(url) {
  const u = new URL(url);
  u.hash = '';
  u.search = '';
  u.hostname = u.hostname.toLowerCase();
  return u.href.replace(/\/+$/, '');
}

/** Identifiant stable d'une proposition : empêche les doublons d'un passage à l'autre. */
export function idProposition(url) {
  return createHash('sha1').update(normaliserUrl(url)).digest('hex').slice(0, 20);
}

export function sansAccents(texte) {
  return String(texte ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}

export function lienHttps(url) {
  try {
    const u = new URL(String(url ?? ''));
    return u.protocol === 'https:' ? u.href : null;
  } catch {
    return null;
  }
}

function niveauValide(valeur) {
  const v = sansAccents(valeur);
  if (v.startsWith('inter')) return 'Intermédiaire';
  if (v.startsWith('avan')) return 'Avancé';
  if (v.startsWith('deb')) return 'Débutant';
  return null;
}

function dateFinValide(valeur) {
  if (typeof valeur !== 'string' || !/^\d{4}-\d{2}-\d{2}/.test(valeur)) return null;
  const d = new Date(valeur.slice(0, 10) + 'T23:59:59');
  return Number.isNaN(d.getTime()) ? null : d;
}

function couper(texte, max) {
  const t = String(texte ?? '').replace(/\s+/g, ' ').trim();
  if (t.length <= max) return t;
  return t.slice(0, max - 1).replace(/\s+\S*$/, '') + '…';
}

/**
 * Contrôle la réponse de l'IA contre les critères. Retourne
 * { ok: true, cours } ou { ok: false, raison }. L'adresse du cours est celle
 * de la page lue, jamais celle « devinée » par l'IA.
 */
export function validerExtraction(brut, urlPage, criteres, maintenant = new Date()) {
  if (!brut || typeof brut !== 'object') return { ok: false, raison: 'réponse illisible' };
  if (brut.estUnCours !== true) return { ok: false, raison: 'la page n\'est pas un cours' };
  if (criteres.gratuitObligatoire && brut.gratuit !== true) return { ok: false, raison: 'cours non gratuit' };

  const titre = couper(brut.titre, 200);
  if (!titre) return { ok: false, raison: 'titre manquant' };

  const langue = String(brut.langue ?? '').trim();
  const langues = (criteres.langues ?? []).map(sansAccents);
  if (langues.length && !langues.includes(sansAccents(langue))) {
    return { ok: false, raison: `langue « ${langue || 'inconnue'} » non retenue` };
  }

  const confiance = Number(brut.confiance);
  if (!Number.isFinite(confiance) || confiance < (criteres.confianceMinimale ?? 0)) {
    return { ok: false, raison: `confiance trop faible (${brut.confiance})` };
  }

  const niveau = niveauValide(brut.niveau) ?? 'Débutant';
  if (criteres.niveauxAcceptes?.length && !criteres.niveauxAcceptes.includes(niveau)) {
    return { ok: false, raison: `niveau ${niveau} non retenu` };
  }

  const description = couper(brut.description, 220);
  const descriptionDetaillee = couper(brut.descriptionDetaillee, 1500) || description;
  if (!description) return { ok: false, raison: 'description manquante' };

  const fournisseur = couper(brut.fournisseur, 80);
  const categorie = couper(brut.categorie, 60);
  if (!fournisseur || !categorie) return { ok: false, raison: 'plateforme ou catégorie manquante' };

  const dateFin = dateFinValide(brut.dateFin);
  if (dateFin && dateFin < maintenant) return { ok: false, raison: 'date de fin déjà passée' };

  const certificatDisponible = brut.certificatDisponible === true;
  return {
    ok: true,
    cours: {
      titre,
      description,
      descriptionDetaillee,
      fournisseur,
      niveau,
      duree: couper(brut.duree, 60) || null,
      langue,
      certificatDisponible,
      certificatPayant: certificatDisponible && brut.certificatPayant === true,
      categorie,
      lienImage: lienHttps(brut.lienImage),
      lienCours: normaliserUrl(urlPage),
      actif: true,
      ordreAffichage: null,
      dateFin,
    },
    confiance,
    remarques: couper(brut.remarques, 300),
  };
}
