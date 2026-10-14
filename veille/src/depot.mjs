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

  // ---------- Demandes de lancement et état de la veille ----------

  /** Identifiants des demandes « en_attente », les plus anciennes d'abord. */
  async demandesEnAttente() {
    const s = await this.db.collection('veille_demandes').where('statut', '==', 'en_attente').get();
    return s.docs
      .sort((a, b) => (a.data().dateDemande?.toMillis?.() ?? 0) - (b.data().dateDemande?.toMillis?.() ?? 0))
      .map((d) => d.id);
  }

  /** Demandes « en_cours » depuis trop longtemps (tâche interrompue) : marquées en erreur. */
  async debloquerDemandes(minutes) {
    const limite = Date.now() - minutes * 60 * 1000;
    const s = await this.db.collection('veille_demandes').where('statut', '==', 'en_cours').get();
    let n = 0;
    for (const d of s.docs) {
      const depuis = d.data().dateMaj?.toMillis?.() ?? d.data().dateDemande?.toMillis?.() ?? 0;
      if (depuis < limite) {
        await d.ref.update({ statut: 'erreur', message: 'Interrompue (la tâche ne s\'est pas terminée).', dateMaj: FieldValue.serverTimestamp() });
        n++;
      }
    }
    return n;
  }

  async majDemande(id, champs) {
    await this.db.collection('veille_demandes').doc(id).update({ ...champs, dateMaj: FieldValue.serverTimestamp() });
  }

  async commencerEtat(champs) {
    await this.db.collection('veille_etat').doc('courant').set({ ...champs, debut: FieldValue.serverTimestamp(), fin: null });
  }

  async terminerEtat(champs) {
    await this.db.collection('veille_etat').doc('courant').set({ ...champs, fin: FieldValue.serverTimestamp() }, { merge: true });
  }
}
