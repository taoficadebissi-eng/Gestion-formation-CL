// File d'attente des lancements demandés depuis l'application, et état de la
// dernière veille (affiché dans l'application). La logique ne dépend que de
// l'objet « depot » : entièrement testable avec un faux dépôt.

export function messageBilan(bilan) {
  const morceaux = [
    `${bilan.proposes} proposition${bilan.proposes > 1 ? 's' : ''} ajoutée${bilan.proposes > 1 ? 's' : ''}`,
    `${bilan.ignores} page${bilan.ignores > 1 ? 's' : ''} écartée${bilan.ignores > 1 ? 's' : ''}`,
  ];
  if (bilan.erreurs) morceaux.push(`${bilan.erreurs} erreur${bilan.erreurs > 1 ? 's' : ''}`);
  let texte = morceaux.join(', ') + '.';
  if (bilan.arret) texte += ` Arrêt anticipé : ${bilan.arret} (reprise au prochain passage).`;
  return texte;
}

/** Une veille qui n'a rien produit et n'a eu que des erreurs est un échec. */
export function statutBilan(bilan) {
  return bilan.proposes === 0 && bilan.ignores === 0 && bilan.erreurs > 0 ? 'erreur' : 'termine';
}

/**
 * Exécute une veille en tenant l'état à jour (en cours → terminé / erreur) et
 * en refermant les demandes associées.
 */
export async function executerAvecEtat({ depot, lancer, declencheur, ids = [], journal = console.log }) {
  await depot.commencerEtat({ statut: 'en_cours', declencheur, message: 'Veille en cours…', proposes: 0, ignores: 0, erreurs: 0, dejaVus: 0 });
  for (const id of ids) await depot.majDemande(id, { statut: 'en_cours' });

  let statut;
  let message;
  let chiffres = {};
  try {
    const bilan = await lancer();
    statut = statutBilan(bilan);
    message = statut === 'erreur'
      ? 'Échec : toutes les pages ont provoqué une erreur (détails dans le journal GitHub).'
      : messageBilan(bilan);
    chiffres = { proposes: bilan.proposes, ignores: bilan.ignores, erreurs: bilan.erreurs, dejaVus: bilan.dejaVus };
  } catch (e) {
    statut = 'erreur';
    message = `Échec : ${String(e.message ?? e).slice(0, 300)}`;
  }
  journal(`État final : ${statut} — ${message}`);
  await depot.terminerEtat({ statut, message, ...chiffres });
  for (const id of ids) await depot.majDemande(id, { statut: statut === 'erreur' ? 'erreur' : 'termine', message });
  return { statut, message };
}

/** Passage « demandes » : ne fait rien (et très vite) s'il n'y a aucune demande. */
export async function traiterDemandes({ depot, lancer, journal = console.log, minutesBloquee = 90 }) {
  const debloquees = await depot.debloquerDemandes(minutesBloquee);
  if (debloquees) journal(`${debloquees} demande(s) bloquée(s) marquée(s) en erreur.`);
  const ids = await depot.demandesEnAttente();
  if (!ids.length) {
    journal('Aucune demande en attente.');
    return { traite: false };
  }
  journal(`${ids.length} demande(s) en attente : lancement de la veille.`);
  const resultat = await executerAvecEtat({ depot, lancer, declencheur: 'bouton', ids, journal });
  return { traite: true, ...resultat };
}
