// Edge Function "enregistrer-paiement" (Phase 5 du cahier des charges).
//
// Seul chemin autorisé à écrire montant_paye / montant_restant /
// statut_paiement sur `inscriptions` (voir le trigger
// prevent_direct_payment_change dans supabase/migrations/0002_phase2.sql,
// qui bloque toute écriture directe de ces champs sauf pour l'admin
// propriétaire du centre ou, comme ici, une requête en service_role).
//
// Pour l'instant ne gère que le paiement manuel saisi par l'admin
// (ex: espèces, virement) — l'intégration Mobile Money (Fedapay/KKiaPay)
// est une sous-étape séparée : quand elle sera branchée, un webhook du
// fournisseur appellera cette même fonction (ou une variante), avec sa
// propre vérification de signature à la place de la vérification de JWT
// admin ci-dessous.
//
// Déploiement : Supabase Dashboard > Edge Functions > Create Function
// (nom : enregistrer-paiement), coller ce fichier, Deploy. Ou via la CLI :
// `supabase functions deploy enregistrer-paiement`.
//
// Appelé depuis l'app via `supabase.functions.invoke('enregistrer-paiement', ...)`
// (voir lib/services/inscription_service.dart, enregistrerPaiement()).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { inscriptionId, montant, methode, reference } = await req.json();

    if (!inscriptionId || typeof montant !== 'number' || montant <= 0) {
      return jsonResponse({ error: 'Parametres invalides' }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization');

    if (!authHeader) {
      return jsonResponse({ error: 'Non authentifie' }, 401);
    }

    // Client avec le JWT de l'appelant, uniquement pour l'identifier.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: 'Non authentifie' }, 401);
    }

    // Client service_role pour les écritures — bypasse RLS, mais on fait
    // nous-mêmes la vérification d'autorisation ci-dessous avant d'écrire.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: inscription, error: inscriptionError } = await adminClient
      .from('inscriptions')
      .select('id, centre_id, formation_id, montant_paye, statut_paiement')
      .eq('id', inscriptionId)
      .single();

    if (inscriptionError || !inscription) {
      return jsonResponse({ error: 'Inscription introuvable' }, 404);
    }

    const { data: centre, error: centreError } = await adminClient
      .from('centres')
      .select('admin_id')
      .eq('id', inscription.centre_id)
      .single();

    if (centreError || !centre || centre.admin_id !== user.id) {
      return jsonResponse(
        { error: "Reserve a l'admin proprietaire du centre" },
        403,
      );
    }

    const { data: formation } = await adminClient
      .from('formations')
      .select('frais_total')
      .eq('id', inscription.formation_id)
      .single();
    const fraisTotal = formation?.frais_total ?? 0;

    const { error: insertError } = await adminClient.from('paiements').insert({
      inscription_id: inscriptionId,
      montant,
      methode: methode ?? 'manuel',
      reference: reference ?? '',
    });
    if (insertError) throw insertError;

    const nouveauMontantPaye = (inscription.montant_paye ?? 0) + montant;
    const nouveauMontantRestant = Math.max(fraisTotal - nouveauMontantPaye, 0);
    const nouveauStatut =
      nouveauMontantRestant <= 0 ? 'a_jour' : inscription.statut_paiement;

    const { error: updateError } = await adminClient
      .from('inscriptions')
      .update({
        montant_paye: nouveauMontantPaye,
        montant_restant: nouveauMontantRestant,
        statut_paiement: nouveauStatut,
      })
      .eq('id', inscriptionId);
    if (updateError) throw updateError;

    return jsonResponse({
      success: true,
      montantPaye: nouveauMontantPaye,
      montantRestant: nouveauMontantRestant,
      statutPaiement: nouveauStatut,
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
