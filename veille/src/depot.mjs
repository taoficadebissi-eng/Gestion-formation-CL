// Accès Firestore (SDK Admin, compte de service). Le programme n'a besoin que
// de : lire les cours publiés, lire/écrire les propositions.
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { normaliserUrl } from './normalisation.mjs';

export class DepotFirestore {
  constructor(compteDeService) {
    const cle = compteDeService ? JSON.parse(compteDeService) : null;
    this.projet = cle?.project_id ?? 'gestion-de-formation-5b049';
    if (this.projet !== 'gestion-de-formation-5b049') {
      throw new Error(`Le compte de service est celui du projet « ${this.projet} », pas de gestion-de-formation-5b049.`);
    }
    initializeApp({ credential: cle ? cert(cle) : applicationDefault(), projectId: this.projet });
    this.db = getFirestore();
  }

  /** Adresses déjà publiées + identifiants de propositions déjà traitées. */
  async dejaConnus() {
    const [cours, propositions] = await Promise.all([
      this.db.collection('cours_gratuits').select('lienCours', 'categorie').get(),
      this.db.collection('cours_propositions').select().get(),
    ]);
    console.log(`Lecture Firestore : ${cours.size} document(s) dans cours_gratuits, ${propositions.size} dans cours_propositions.`);
    const urls = new Set();
    const categories = new Set();
    for (const doc of cours.docs) {
      const { lienCours, categorie } = doc.data();
      try { if (lienCours) urls.add(normaliserUrl(lienCours)); } catch (e) { console.log(`Lien de cours illisible (${doc.id}) : ${String(lienCours).slice(0, 80)}`); }
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
