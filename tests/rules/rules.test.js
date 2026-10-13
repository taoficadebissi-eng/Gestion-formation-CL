import { readFileSync } from 'node:fs';
import { before, after, beforeEach, describe, it } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs, writeBatch } from 'firebase/firestore';

const SUPER_EMAIL = 'taoficadebissi@gmail.com';
let env;

const ctx = {
  admin: () => env.authenticatedContext('admin1', { email: 'admin1@x.com', email_verified: true }),
  admin2: () => env.authenticatedContext('admin2', { email: 'admin2@x.com', email_verified: true }),
  form: () => env.authenticatedContext('form1', { email: 'form1@x.com', email_verified: true }),
  app: () => env.authenticatedContext('app1', { email: 'app1@x.com', email_verified: true }),
  app2: () => env.authenticatedContext('app2', { email: 'app2@x.com', email_verified: true }),
  app3: () => env.authenticatedContext('app3', { email: 'app3@x.com', email_verified: true }),
  autre: () => env.authenticatedContext('autre1', { email: 'autre@x.com', email_verified: true }),
  nouveau: () => env.authenticatedContext('new1', { email: 'new1@x.com', email_verified: true }),
  sup: () => env.authenticatedContext('sup', { email: SUPER_EMAIL, email_verified: true }),
  supNonVerifie: () => env.authenticatedContext('sup2', { email: SUPER_EMAIL, email_verified: false }),
  nonVerifie: () => env.authenticatedContext('nv1', { email: 'nv1@x.com', email_verified: false }),
  anon: () => env.unauthenticatedContext(),
};
const db = (c) => c.firestore();

const profil = (id, role, centre) => ({
  id, nom: 'N', prenom: 'P', email: `${id}@x.com`, role, centre_id: centre, is_first_login: false,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gestion',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const d = c.firestore();
    await setDoc(doc(d, 'users/admin1'), profil('admin1', 'admin', null));
    await setDoc(doc(d, 'users/admin2'), profil('admin2', 'admin', null));
    await setDoc(doc(d, 'users/form1'), profil('form1', 'formateur', 'c1'));
    await setDoc(doc(d, 'users/app1'), profil('app1', 'apprenant', 'c1'));
    await setDoc(doc(d, 'users/app2'), profil('app2', 'apprenant', 'c1'));
    await setDoc(doc(d, 'users/app3'), profil('app3', 'apprenant', 'c2'));
    await setDoc(doc(d, 'users/autre1'), profil('autre1', 'apprenant', 'c2'));
    await setDoc(doc(d, 'centres/c1'), { nom: 'C1', admin_id: 'admin1', ville: 'v', pays: 'p', date_creation: 'x', actif: true });
    await setDoc(doc(d, 'centres/c2'), { nom: 'C2', admin_id: 'admin2', ville: 'v', pays: 'p', date_creation: 'x', actif: true });
    await setDoc(doc(d, 'formations/f1'), { titre: 't', description: 'd', formateur_id: 'form1', formateur_nom: 'F', nombre_sessions: 1, niveau: 'n', date_creation: 'x', date_debut: 'x', date_fin: 'x', centre_id: 'c1', prerequis_id: null, frais_total: 100, image_url: null });
    await setDoc(doc(d, 'inscriptions/app2_f1'), { apprenant_id: 'app2', apprenant_nom: 'A2', formation_id: 'f1', centre_id: 'c1', date_inscription: 'x', statut: 'confirmee', statut_paiement: 'bloque', montant_paye: 0, montant_restant: 100 });
    await setDoc(doc(d, 'inscriptions/app1_f1'), { apprenant_id: 'app1', apprenant_nom: 'A1', formation_id: 'f1', centre_id: 'c1', date_inscription: 'x', statut: 'confirmee', statut_paiement: 'a_jour', montant_paye: 0, montant_restant: 100 });
    await setDoc(doc(d, 'notes/n1'), { formation_id: 'f1', nom_fichier: 'x', url: 'https://a.b/c', uploade_par: 'form1', date_ajout: 'x' });
    await setDoc(doc(d, 'invitations/INV-AAAA-BBBB'), { token: 'INV-AAAA-BBBB', utilise: false, admin_id: null, date_creation: 'x' });
  });
});

const inscriptionApprenant = (over = {}) => ({
  apprenant_id: 'app1', apprenant_nom: 'A1', formation_id: 'f1', centre_id: 'c1',
  date_inscription: 'x', statut: 'enAttente', statut_paiement: 'a_jour',
  montant_paye: 0, montant_restant: 100, ...over,
});

describe('invitations & super-admin', () => {
  it('seul le super-admin verifie liste et cree les codes', async () => {
    await assertSucceeds(getDocs(collection(db(ctx.sup()), 'invitations')));
    await assertFails(getDocs(collection(db(ctx.supNonVerifie()), 'invitations')));
    await assertFails(getDocs(collection(db(ctx.admin()), 'invitations')));
    await assertFails(getDocs(collection(db(ctx.anon()), 'invitations')));
    await assertSucceeds(setDoc(doc(db(ctx.sup()), 'invitations/INV-NEW-CODE1'), { token: 'INV-NEW-CODE1', utilise: false, admin_id: null, date_creation: 'x' }));
    await assertFails(setDoc(doc(db(ctx.autre()), 'invitations/INV-HACK-CODE1'), { token: 'INV-HACK-CODE1', utilise: false, admin_id: null, date_creation: 'x' }));
    await assertFails(deleteDoc(doc(db(ctx.autre()), 'invitations/INV-AAAA-BBBB')));
  });

  it('un code precis peut etre lu par un connecte mais pas par un anonyme', async () => {
    await assertSucceeds(getDoc(doc(db(ctx.nouveau()), 'invitations/INV-AAAA-BBBB')));
    await assertFails(getDoc(doc(db(ctx.anon()), 'invitations/INV-AAAA-BBBB')));
  });

  it('inscription admin: profil + consommation du code dans le meme batch', async () => {
    const d = db(ctx.nouveau());
    const b = writeBatch(d);
    b.set(doc(d, 'users/new1'), { ...profil('new1', 'admin', null), email: 'new1@x.com', invitation_token: 'INV-AAAA-BBBB' });
    b.update(doc(d, 'invitations/INV-AAAA-BBBB'), { utilise: true, admin_id: 'new1' });
    await assertSucceeds(b.commit());
  });

  it('inscription admin sans code valide ou sans consommation: refusee', async () => {
    const d = db(ctx.nouveau());
    await assertFails(setDoc(doc(d, 'users/new1'), { ...profil('new1', 'admin', null), email: 'new1@x.com', invitation_token: 'INV-AAAA-BBBB' }));
    const b = writeBatch(d);
    b.set(doc(d, 'users/new1'), { ...profil('new1', 'admin', null), email: 'new1@x.com', invitation_token: 'INV-INCONNU-X' });
    b.update(doc(d, 'invitations/INV-AAAA-BBBB'), { utilise: true, admin_id: 'new1' });
    await assertFails(b.commit());
  });

  it('un code deja utilise ne peut plus servir', async () => {
    await env.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'invitations/INV-AAAA-BBBB'), { token: 'INV-AAAA-BBBB', utilise: true, admin_id: 'x', date_creation: 'x' });
    });
    const d = db(ctx.nouveau());
    const b = writeBatch(d);
    b.set(doc(d, 'users/new1'), { ...profil('new1', 'admin', null), email: 'new1@x.com', invitation_token: 'INV-AAAA-BBBB' });
    b.update(doc(d, 'invitations/INV-AAAA-BBBB'), { utilise: true, admin_id: 'new1' });
    await assertFails(b.commit());
  });

  it('auto-inscription en formateur ou admin sans invitation: refusee', async () => {
    const d = db(ctx.nouveau());
    await assertFails(setDoc(doc(d, 'users/new1'), profil('new1', 'formateur', 'c1')));
    await assertFails(setDoc(doc(d, 'users/new1'), profil('new1', 'admin', null)));
  });
});

describe('utilisateurs', () => {
  it("l'admin proprietaire cree un apprenant dans son centre, pas dans un autre", async () => {
    await assertSucceeds(setDoc(doc(db(ctx.admin()), 'users/u9'), { ...profil('u9', 'apprenant', 'c1'), is_first_login: true }));
    await assertFails(setDoc(doc(db(ctx.admin()), 'users/u8'), { ...profil('u8', 'apprenant', 'c2'), is_first_login: true }));
    await assertFails(setDoc(doc(db(ctx.admin()), 'users/u7'), { ...profil('u7', 'admin', null), is_first_login: true }));
  });

  it('lecture limitee au centre ; changement de role interdit', async () => {
    await assertSucceeds(getDocs(query(collection(db(ctx.app()), 'users'), where('centre_id', '==', 'c1'))));
    await assertFails(getDocs(query(collection(db(ctx.app()), 'users'), where('centre_id', '==', 'c2'))));
    await assertSucceeds(getDocs(query(collection(db(ctx.admin()), 'users'), where('centre_id', '==', 'c1'))));
    await assertFails(getDocs(query(collection(db(ctx.admin()), 'users'), where('centre_id', '==', 'c2'))));
    await assertFails(updateDoc(doc(db(ctx.app()), 'users/app1'), { role: 'admin' }));
    await assertFails(updateDoc(doc(db(ctx.app()), 'users/app1'), { centre_id: 'c2' }));
    await assertSucceeds(updateDoc(doc(db(ctx.app()), 'users/app1'), { is_first_login: false }));
  });
});

describe('centres, formations', () => {
  it('isolation entre centres', async () => {
    await assertSucceeds(getDocs(query(collection(db(ctx.admin()), 'centres'), where('admin_id', '==', 'admin1'))));
    await assertFails(getDocs(query(collection(db(ctx.admin()), 'centres'), where('admin_id', '==', 'admin2'))));
    await assertSucceeds(getDoc(doc(db(ctx.app()), 'centres/c1')));
    await assertFails(getDoc(doc(db(ctx.app()), 'centres/c2')));
    await assertFails(updateDoc(doc(db(ctx.admin2()), 'centres/c1'), { nom: 'hack' }));
  });

  it('formations: lecture par centre, ecriture par proprietaire/formateur', async () => {
    await assertSucceeds(getDocs(query(collection(db(ctx.app()), 'formations'), where('centre_id', '==', 'c1'))));
    await assertFails(getDocs(query(collection(db(ctx.autre()), 'formations'), where('centre_id', '==', 'c1'))));
    await assertFails(updateDoc(doc(db(ctx.app()), 'formations/f1'), { titre: 'x' }));
    await assertSucceeds(updateDoc(doc(db(ctx.form()), 'formations/f1'), { titre: 'x' }));
    await assertFails(updateDoc(doc(db(ctx.form()), 'formations/f1'), { centre_id: 'c2' }));
    await assertSucceeds(updateDoc(doc(db(ctx.admin()), 'formations/f1'), { titre: 'y' }));
    await assertFails(updateDoc(doc(db(ctx.admin2()), 'formations/f1'), { titre: 'z' }));
  });
});

describe('inscriptions & paiements', () => {
  it("un apprenant s'inscrit avec l'etat de paiement initial seulement", async () => {
    await env.withSecurityRulesDisabled(async (c) => deleteDoc(doc(c.firestore(), 'inscriptions/app1_f1')));
    const d = db(ctx.app());
    await assertFails(setDoc(doc(d, 'inscriptions/app1_f1'), inscriptionApprenant({ montant_restant: 0 })));
    await assertFails(setDoc(doc(d, 'inscriptions/app1_f1'), inscriptionApprenant({ statut_paiement: 'bloque' })));
    await assertFails(setDoc(doc(d, 'inscriptions/app1_f1'), inscriptionApprenant({ montant_paye: 50 })));
    await assertFails(setDoc(doc(d, 'inscriptions/mauvais_id'), inscriptionApprenant()));
    await assertFails(setDoc(doc(d, 'inscriptions/app2_f1'), inscriptionApprenant({ apprenant_id: 'app2' })));
    await assertSucceeds(setDoc(doc(d, 'inscriptions/app1_f1'), inscriptionApprenant()));
  });

  it('un apprenant ne modifie pas ses champs de paiement', async () => {
    const d = db(ctx.app());
    await assertFails(updateDoc(doc(d, 'inscriptions/app1_f1'), { statut_paiement: 'a_jour', montant_restant: 0 }));
    await assertFails(updateDoc(doc(d, 'inscriptions/app1_f1'), { montant_paye: 100 }));
    await assertSucceeds(updateDoc(doc(d, 'inscriptions/app1_f1'), { statut: 'annulee' }));
    await assertFails(updateDoc(doc(db(ctx.form()), 'inscriptions/app1_f1'), { montant_paye: 100 }));
  });

  it("un apprenant bloque ou ayant paye ne peut pas effacer son inscription", async () => {
    await assertFails(deleteDoc(doc(db(ctx.app2()), 'inscriptions/app2_f1')));
    await env.withSecurityRulesDisabled(async (c) => updateDoc(doc(c.firestore(), 'inscriptions/app1_f1'), { montant_paye: 10 }));
    await assertFails(deleteDoc(doc(db(ctx.app()), 'inscriptions/app1_f1')));
    await assertSucceeds(deleteDoc(doc(db(ctx.admin()), 'inscriptions/app1_f1')));
  });

  it('lecture: ses propres inscriptions seulement', async () => {
    await assertSucceeds(getDocs(query(collection(db(ctx.app()), 'inscriptions'), where('apprenant_id', '==', 'app1'))));
    await assertFails(getDocs(query(collection(db(ctx.app()), 'inscriptions'), where('apprenant_id', '==', 'app2'))));
    await assertSucceeds(getDocs(query(collection(db(ctx.form()), 'inscriptions'), where('centre_id', '==', 'c1'), where('formation_id', '==', 'f1'))));
    await assertFails(getDocs(query(collection(db(ctx.autre()), 'inscriptions'), where('centre_id', '==', 'c1'))));
    await assertSucceeds(getDoc(doc(db(ctx.app3()), 'inscriptions/app3_f1')));
    await assertFails(getDoc(doc(db(ctx.app3()), 'inscriptions/app1_f1')));
  });

  it("paiement: admin proprietaire, total coherent, dans un batch", async () => {
    const d = db(ctx.admin());
    const ok = writeBatch(d);
    ok.set(doc(d, 'paiements/p1'), { inscription_id: 'app1_f1', montant: 40, date: 'x', methode: 'manuel', reference: '' });
    ok.update(doc(d, 'inscriptions/app1_f1'), { montant_paye: 40, montant_restant: 60 });
    await assertSucceeds(ok.commit());

    const incoherent = writeBatch(d);
    incoherent.set(doc(d, 'paiements/p2'), { inscription_id: 'app1_f1', montant: 40, date: 'x', methode: 'manuel', reference: '' });
    incoherent.update(doc(d, 'inscriptions/app1_f1'), { montant_paye: 500, montant_restant: 0 });
    await assertFails(incoherent.commit());

    await assertFails(setDoc(doc(d, 'paiements/p3'), { inscription_id: 'app1_f1', montant: 40, date: 'x', methode: 'manuel', reference: '' }));
    await assertFails(updateDoc(doc(d, 'paiements/p1'), { montant: 1 }));

    const dApp = db(ctx.app());
    await assertFails(setDoc(doc(dApp, 'paiements/p4'), { inscription_id: 'app1_f1', montant: 10, date: 'x', methode: 'manuel', reference: '' }));
    await assertSucceeds(getDocs(query(collection(dApp, 'paiements'), where('inscription_id', '==', 'app1_f1'))));
    await assertFails(getDocs(query(collection(db(ctx.app2()), 'paiements'), where('inscription_id', '==', 'app1_f1'))));
  });
});

describe('notes et messages', () => {
  it('notes visibles par inscrits non bloques, formateur et admin', async () => {
    const q = (c) => getDocs(query(collection(db(c), 'notes'), where('formation_id', '==', 'f1')));
    await assertSucceeds(q(ctx.app()));
    await assertFails(q(ctx.app2())); // bloque
    await assertFails(q(ctx.app3())); // non inscrit
    await assertSucceeds(q(ctx.form()));
    await assertSucceeds(q(ctx.admin()));
    await assertFails(q(ctx.admin2()));
  });

  it("notes: lien https obligatoire, ecriture par formateur de la formation", async () => {
    const note = (over = {}) => ({ formation_id: 'f1', nom_fichier: 'Cours', url: 'https://drive.google.com/x', uploade_par: 'form1', date_ajout: 'x', ...over });
    await assertSucceeds(setDoc(doc(db(ctx.form()), 'notes/n2'), note()));
    await assertFails(setDoc(doc(db(ctx.form()), 'notes/n3'), note({ url: 'javascript:alert(1)' })));
    await assertFails(setDoc(doc(db(ctx.form()), 'notes/n4'), note({ uploade_par: 'autre' })));
    await assertFails(setDoc(doc(db(ctx.app()), 'notes/n5'), note({ uploade_par: 'app1' })));
  });

  it('chat de groupe: membres non bloques seulement', async () => {
    const msg = (auteur) => ({ formation_id: 'f1', auteur_id: auteur, texte: 'salut', date_envoi: 'x' });
    await assertSucceeds(setDoc(doc(db(ctx.app()), 'messages/m1'), msg('app1')));
    await assertFails(setDoc(doc(db(ctx.app()), 'messages/m2'), msg('app2')));
    await assertFails(setDoc(doc(db(ctx.app2()), 'messages/m3'), msg('app2')));
    await assertFails(setDoc(doc(db(ctx.app3()), 'messages/m4'), msg('app3')));
    await assertSucceeds(setDoc(doc(db(ctx.form()), 'messages/m5'), msg('form1')));
  });

  it('messagerie admin: seulement les deux participants', async () => {
    const id = 'c1_app1_admin1';
    const conv = { centre_id: 'c1', participants: ['app1', 'admin1'], dernier_message: null, date_maj: 'x' };
    await assertSucceeds(setDoc(doc(db(ctx.app()), `messages_admin_conversations/${id}`), conv));
    await assertFails(setDoc(doc(db(ctx.app2()), `messages_admin_conversations/c1_app1_admin1x`), conv));
    await assertSucceeds(getDoc(doc(db(ctx.admin()), `messages_admin_conversations/${id}`)));
    await assertFails(getDoc(doc(db(ctx.app2()), `messages_admin_conversations/${id}`)));
    await assertSucceeds(setDoc(doc(db(ctx.admin()), 'messages_admin/x1'), { conversation_id: id, auteur_id: 'admin1', texte: 'hello', date_envoi: 'x' }));
    await assertFails(setDoc(doc(db(ctx.app2()), 'messages_admin/x2'), { conversation_id: id, auteur_id: 'app2', texte: 'hello', date_envoi: 'x' }));
    await assertSucceeds(getDocs(query(collection(db(ctx.app()), 'messages_admin'), where('conversation_id', '==', id))));
    await assertFails(getDocs(query(collection(db(ctx.app2()), 'messages_admin'), where('conversation_id', '==', id))));
  });
});

describe('presences', () => {
  it('formateur ecrit, apprenant lit seulement les siennes', async () => {
    const p = { session_id: 's1', formation_id: 'f1', centre_id: 'c1', apprenant_id: 'app1', apprenant_nom: 'A1', present: true, date: 'x' };
    await assertSucceeds(setDoc(doc(db(ctx.form()), 'presences/s1_app1'), p));
    await assertFails(setDoc(doc(db(ctx.app()), 'presences/s1_app1'), p));
    await assertFails(setDoc(doc(db(ctx.form()), 'presences/mauvais'), p));
    await assertSucceeds(getDocs(query(collection(db(ctx.app()), 'presences'), where('centre_id', '==', 'c1'), where('apprenant_id', '==', 'app1'), where('formation_id', '==', 'f1'))));
    await assertFails(getDocs(query(collection(db(ctx.app2()), 'presences'), where('centre_id', '==', 'c1'), where('apprenant_id', '==', 'app1'))));
  });
});

describe('CoursLibre (meme projet)', () => {
  it('cours: lecture publique, ecriture super-admin avec liens https', async () => {
    const cours = (over = {}) => ({ titre: 'x', lienCours: 'https://coursera.org/x', lienImage: null, ...over });
    await assertSucceeds(getDocs(collection(db(ctx.anon()), 'cours_gratuits')));
    await assertSucceeds(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c1'), cours()));
    await assertSucceeds(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c5'), cours({ lienImage: 'https://img.io/a.png' })));
    await assertFails(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c6'), cours({ lienCours: 'javascript:alert(1)' })));
    await assertFails(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c7'), cours({ lienImage: 'http://x.io/a.png' })));
    await assertFails(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c8'), cours({ titre: '' })));
    await assertSucceeds(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c9'), cours({ dateFin: new Date('2030-01-01') })));
    await assertSucceeds(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c10'), cours({ dateFin: null })));
    await assertFails(setDoc(doc(db(ctx.sup()), 'cours_gratuits/c11'), cours({ dateFin: 'demain' })));
    await assertFails(setDoc(doc(db(ctx.admin()), 'cours_gratuits/c2'), cours()));
    await assertFails(setDoc(doc(db(ctx.supNonVerifie()), 'cours_gratuits/c3'), cours()));
    await assertFails(setDoc(doc(db(ctx.anon()), 'cours_gratuits/c4'), cours()));
    await assertSucceeds(deleteDoc(doc(db(ctx.sup()), 'cours_gratuits/c1')));
    await assertFails(deleteDoc(doc(db(ctx.admin()), 'cours_gratuits/c5')));
  });

  it('compteur: +1 anonyme uniquement', async () => {
    const ref = (c) => doc(db(c), 'compteur/visiteurs');
    await assertSucceeds(setDoc(ref(ctx.anon()), { total: 1 }));
    await assertSucceeds(setDoc(ref(ctx.anon()), { total: 2 }));
    await assertFails(setDoc(ref(ctx.anon()), { total: 500 }));
    await assertFails(setDoc(ref(ctx.anon()), { total: 3, autre: 1 }));
    await assertFails(deleteDoc(ref(ctx.sup())));
  });
});

describe('e-mail non verifie', () => {
  it("un compte non verifie n'a acces a rien, sauf lire un code precis", async () => {
    await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/nv1'), profil('nv1', 'apprenant', 'c1')));
    const d = db(ctx.nonVerifie());
    await assertFails(getDoc(doc(d, 'users/nv1')));
    await assertFails(getDocs(query(collection(d, 'formations'), where('centre_id', '==', 'c1'))));
    await assertSucceeds(getDoc(doc(d, 'invitations/INV-AAAA-BBBB')));
    await assertFails(getDocs(collection(d, 'invitations')));
  });

  it("l'inscription admin exige un e-mail verifie", async () => {
    const d = db(ctx.nonVerifie());
    const b = writeBatch(d);
    b.set(doc(d, 'users/nv1'), { ...profil('nv1', 'admin', null), email: 'nv1@x.com', invitation_token: 'INV-AAAA-BBBB' });
    b.update(doc(d, 'invitations/INV-AAAA-BBBB'), { utilise: true, admin_id: 'nv1' });
    await assertFails(b.commit());
  });
});
