-- Migration 0002 — Phase 2 du cahier des charges : restructuration du
-- schéma pour préparer les Phases 3 à 6 (notes de cours, prérequis entre
-- formations, paiements, messagerie). Schéma et policies RLS uniquement —
-- aucun écran Flutter n'est branché sur ces tables dans cette phase, elles
-- seront consommées progressivement dans les phases suivantes.
--
-- À exécuter dans Supabase Dashboard > SQL Editor, après 0001_foundations.sql.
--
-- Note d'architecture : le cahier des charges original a été écrit pour
-- Firestore et parle de "sous-collections" (formations/{id}/notes,
-- formations/{id}/messages, centres/{id}/messagesAdmin/{id}/messages).
-- Sur Postgres/Supabase, l'équivalent naturel est une table séparée avec
-- une clé étrangère, ce qui est ce qui est fait ici — le comportement
-- fonctionnel décrit dans le cahier (qui peut lire/écrire quoi) est
-- reproduit à l'identique via les policies RLS ci-dessous.
--
-- Pas de script de migration de données séparé nécessaire : les nouvelles
-- colonnes sur `formations` et `inscriptions` ont des valeurs par défaut
-- (`default 0`, `default null`, `default 'a_jour'`), automatiquement
-- appliquées par Postgres aux lignes existantes lors de l'ADD COLUMN.

-- ========================================
-- FORMATIONS : prérequis + frais total
-- ========================================

alter table public.formations
  add column prerequis_id uuid references public.formations(id) on delete set null,
  add column frais_total numeric(12, 2) not null default 0;

-- ========================================
-- INSCRIPTIONS : statut de paiement
-- ========================================

alter table public.inscriptions
  add column statut_paiement text not null default 'a_jour'
    check (statut_paiement in ('a_jour', 'en_retard', 'bloque')),
  add column montant_paye numeric(12, 2) not null default 0,
  add column montant_restant numeric(12, 2) not null default 0;

-- ========================================
-- NOTES DE COURS (Phase 3)
-- ========================================

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  formation_id uuid not null references public.formations(id) on delete cascade,
  nom_fichier text not null,
  url text not null,
  uploade_par uuid not null references auth.users(id) on delete set null,
  date_ajout timestamptz not null default now()
);

-- ========================================
-- PAIEMENTS (Phase 5)
-- ========================================

create table public.paiements (
  id uuid primary key default gen_random_uuid(),
  inscription_id uuid not null references public.inscriptions(id) on delete cascade,
  montant numeric(12, 2) not null,
  date timestamptz not null default now(),
  methode text not null default '',
  reference text not null default ''
);

-- ========================================
-- MESSAGERIE (Phase 6)
-- ========================================

-- Chat de groupe par formation.
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  formation_id uuid not null references public.formations(id) on delete cascade,
  auteur_id uuid not null references auth.users(id) on delete cascade,
  texte text not null,
  date_envoi timestamptz not null default now()
);

-- Messagerie admin <-> apprenant (1-a-1). `participants` contient les 2
-- uid (admin + apprenant) — reproduit le champ "participants" du cahier
-- des charges plutôt que de figer la relation sur des colonnes admin_id/
-- apprenant_id, pour rester fidèle au schéma décrit.
create table public.messages_admin_conversations (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references public.centres(id) on delete cascade,
  participants uuid[] not null,
  dernier_message text,
  date_maj timestamptz not null default now()
);

create table public.messages_admin (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.messages_admin_conversations(id) on delete cascade,
  auteur_id uuid not null references auth.users(id) on delete cascade,
  texte text not null,
  date_envoi timestamptz not null default now()
);

-- ========================================
-- FONCTIONS HELPER (nouvelles, pour les policies ci-dessous)
-- ========================================

create or replace function public.is_inscrit_formation(target_formation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.inscriptions
    where formation_id = target_formation_id and apprenant_id = auth.uid()
  );
$$;

create or replace function public.is_formateur_de_formation(target_formation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.formations
    where id = target_formation_id and formateur_id = auth.uid()
  );
$$;

create or replace function public.is_admin_owner_de_formation(target_formation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.formations f
    where f.id = target_formation_id and public.is_owner_of_centre(f.centre_id)
  );
$$;

create or replace function public.get_inscription_apprenant(target_inscription_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select apprenant_id from public.inscriptions where id = target_inscription_id;
$$;

create or replace function public.get_inscription_centre(target_inscription_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select centre_id from public.inscriptions where id = target_inscription_id;
$$;

-- ========================================
-- PROTECTION DU STATUT DE PAIEMENT
-- ========================================
-- "L'apprenant peut lire son propre document, mais ne peut jamais écrire
-- statutPaiement, montantPaye, montantRestant — seul l'admin (ou une Cloud
-- Function) peut modifier ces champs." La policy UPDATE existante sur
-- inscriptions (voir 0001_foundations.sql) autorise l'apprenant à modifier
-- sa propre ligne pour d'autres raisons (elle date d'avant l'existence des
-- champs de paiement) : un trigger BEFORE UPDATE referme spécifiquement
-- ces 3 colonnes, pour quiconque n'est pas admin-propriétaire du centre —
-- y compris un formateur, qui ne doit pas non plus pouvoir les modifier
-- directement. `service_role` (utilisé par une future Edge Function, voir
-- Phase 5) passe outre volontairement : c'est le seul chemin serveur
-- habilité à recalculer ces champs après un paiement.
create or replace function public.prevent_direct_payment_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if new.statut_paiement is distinct from old.statut_paiement
     or new.montant_paye is distinct from old.montant_paye
     or new.montant_restant is distinct from old.montant_restant then
    if not public.is_owner_of_centre(old.centre_id) then
      raise exception 'Modification du statut de paiement non autorisee : reservee a l''admin ou a une Edge Function';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_prevent_direct_payment_change
  before update on public.inscriptions
  for each row
  execute function public.prevent_direct_payment_change();

-- ========================================
-- RLS
-- ========================================

alter table public.notes enable row level security;
alter table public.paiements enable row level security;
alter table public.messages enable row level security;
alter table public.messages_admin_conversations enable row level security;
alter table public.messages_admin enable row level security;

-- notes : lecture pour tout apprenant inscrit à la formation, le formateur
-- de la formation, ou l'admin propriétaire du centre. Écriture réservée au
-- formateur de la formation.
create policy "notes_select" on public.notes for select
  using (
    public.is_inscrit_formation(formation_id)
    or public.is_formateur_de_formation(formation_id)
    or public.is_admin_owner_de_formation(formation_id)
  );

create policy "notes_insert" on public.notes for insert
  with check (
    public.is_formateur_de_formation(formation_id) and uploade_par = auth.uid()
  );

create policy "notes_delete" on public.notes for delete
  using (public.is_formateur_de_formation(formation_id));

-- paiements : lecture pour l'apprenant concerné, l'admin propriétaire du
-- centre, ou le formateur du centre. Écriture réservée à l'admin (la
-- Phase 5 branchera aussi une Edge Function en service_role, qui
-- contourne RLS de toute façon).
create policy "paiements_select" on public.paiements for select
  using (
    public.get_inscription_apprenant(inscription_id) = auth.uid()
    or public.is_owner_of_centre(public.get_inscription_centre(inscription_id))
    or (
      public.is_formateur()
      and public.is_user_in_centre(public.get_inscription_centre(inscription_id))
    )
  );

create policy "paiements_insert" on public.paiements for insert
  with check (public.is_owner_of_centre(public.get_inscription_centre(inscription_id)));

-- messages (chat de groupe par formation) : lecture/écriture réservées aux
-- inscrits de la formation, au formateur, et à l'admin propriétaire du
-- centre. La restriction d'accès en cas de statut "bloque" (Phase 5) sera
-- ajoutée à cette policy quand l'application du blocage sera implémentée,
-- pas avant — elle ne fait pas partie du périmètre de cette Phase 2.
create policy "messages_select" on public.messages for select
  using (
    public.is_inscrit_formation(formation_id)
    or public.is_formateur_de_formation(formation_id)
    or public.is_admin_owner_de_formation(formation_id)
  );

create policy "messages_insert" on public.messages for insert
  with check (
    auteur_id = auth.uid()
    and (
      public.is_inscrit_formation(formation_id)
      or public.is_formateur_de_formation(formation_id)
      or public.is_admin_owner_de_formation(formation_id)
    )
  );

-- messagesAdmin : lecture/écriture réservées aux participants de la
-- conversation.
create policy "messages_admin_conversations_select" on public.messages_admin_conversations for select
  using (auth.uid() = any(participants));

create policy "messages_admin_conversations_insert" on public.messages_admin_conversations for insert
  with check (auth.uid() = any(participants));

create policy "messages_admin_conversations_update" on public.messages_admin_conversations for update
  using (auth.uid() = any(participants));

create policy "messages_admin_select" on public.messages_admin for select
  using (
    exists (
      select 1 from public.messages_admin_conversations c
      where c.id = conversation_id and auth.uid() = any(c.participants)
    )
  );

create policy "messages_admin_insert" on public.messages_admin for insert
  with check (
    auteur_id = auth.uid()
    and exists (
      select 1 from public.messages_admin_conversations c
      where c.id = conversation_id and auth.uid() = any(c.participants)
    )
  );

-- ========================================
-- REALTIME
-- ========================================

alter publication supabase_realtime add table
  public.notes,
  public.paiements,
  public.messages,
  public.messages_admin_conversations,
  public.messages_admin;
