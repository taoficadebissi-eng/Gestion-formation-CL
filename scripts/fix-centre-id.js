// C:\gestion\scripts\fix-centre-id.js
const admin = require('firebase-admin');

// Le chemin remonte d'un dossier (..) pour aller chercher la clé à la racine du projet
const serviceAccount = require('../gestion-firebase-adminsdk.json'); 

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// ⚠️ REMPLACE CETTE VALEUR PAR LE VRAI ID DU CENTRE QUI A LE BUG
// Tu peux le trouver dans ta console Firestore > Collection 'centres' > Document du centre concerné
const CENTRE_1_ID = "NZl6oNHTXaLbRCcYBQOJ"; 

async function fixData() {
  console.log(`🔧 Démarrage de la migration pour le centre : ${CENTRE_1_ID}...`);
  
  // 1. Correction des Sessions
  console.log("🔍 Recherche des sessions sans centreId...");
  const sessionsSnap = await db.collection('sessions').where('centreId', '==', null).get();
  
  if (!sessionsSnap.empty) {
    const batch = db.batch();
    sessionsSnap.forEach(doc => batch.update(doc.ref, { centreId: CENTRE_1_ID }));
    await batch.commit();
    console.log(`✅ ${sessionsSnap.size} sessions corrigées.`);
  } else {
    console.log("Aucune session à corriger.");
  }

  // 2. Correction des Inscriptions
  console.log("🔍 Recherche des inscriptions sans centreId...");
  const inscriptionsSnap = await db.collection('inscriptions').where('centreId', '==', null).get();
  
  if (!inscriptionsSnap.empty) {
    const batch = db.batch();
    inscriptionsSnap.forEach(doc => batch.update(doc.ref, { centreId: CENTRE_1_ID }));
    await batch.commit();
    console.log(`✅ ${inscriptionsSnap.size} inscriptions corrigées.`);
  } else {
    console.log("Aucune inscription à corriger.");
  }
  
  console.log("🎉 FINI ! Tes règles Firestore vont maintenant fonctionner.");
}

fixData().catch(err => {
  console.error('❌ Erreur critique:', err);
  process.exit(1);
});