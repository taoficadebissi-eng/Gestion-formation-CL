// Accès Firestore (SDK Admin, compte de service). Le programme n'a besoin que
// de : lire les cours publiés, lire/écrire les propositions.
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { normaliserUrl } from './normalisation.mjs';

export class DepotFirestore {
  constructor(compteDeService) {
    const credential = compteDeService ? cert(JSON.parse(compteDeService)) : applicationDefault();
    initializeApp({ credential, projectId: 'gestion-de-formation-5b049' });
    this.db = getFirestore();
  }

  /** Adresses déjà publiées + identifiants de propositions déjà traitées. */
  async dejaConnus() {
    const [cours, propositions] = await Promise.all([
      this.db.collection('cours_gratuits').select('lienCours', 'categorie').get(),
      this.db.collection('cours_propositions').select().get(),
    ]);
    const urls = new Set();
    const categories = new Set();
    for (const doc of cours.docs) {
      const { lienCours, categorie } = doc.data();
      try { if (lienCours) urls.add(normaliserUrl(lienCours)); } catch { /* ignoré */ }
      if (categorie) categories.add(categorie);
    }
    return { urls, categories: [...categories].sort(), idsPropositions: new Set(propositions.docs.map((d) => d.id)) };
  }

  async enregistrerProposition(id, { cours, confiance, remarques, source }) {
    await this.db.collection('cours_propositions').doc(id).create({
      ...cours,
      dateFin: cours.dateFin ? Timestamp.fromDate(cours.dateFin) : null,
      statut: 'a_valider',
      source: source.id,
      sourceNom: source.nom,
      urlSource: cours.lienCours,
      confiance,
      remarques,
      dateProposition: FieldValue.serverTimestamp(),
    });
  }

  /** Page lue mais écartée : mémorisée pour ne pas être réanalysée (économie de quota). */
  async enregistrerIgnore(id, { url, raison, source }) {
    await this.db.collection('cours_propositions').doc(id).create({
      statut: 'ignore',
      raison,
      source: source.id,
      urlSource: url,
      dateProposition: FieldValue.serverTimestamp(),
    });
  }
}
