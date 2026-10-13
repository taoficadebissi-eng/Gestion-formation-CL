-- Migration 0001 — Fondations Supabase (remplace Firebase Auth + Firestore
-- pour les collections existantes : users, centres, formations, sessions,
-- inscriptions, presences, invitations).
--
-- À exécuter dans Supabase Dashboard > SQL Editor (projet xuvvqkwjkxnyafrqxgta),
-- en une seule fois, sur une base vierge.
--
-- Après exécution, penser à :
--   1) Authentication > Providers > Email > désactiver "Confirm email"
--      (le flux existant crée des comptes avec mot de passe temporaire à
--      changer à la première connexion, sans étape de confirmation email —
--      pour préserver ce comportement à l'identique).
--   2) Database > Replication : vérifier que les tables ci-dessous sont
--      bien ajoutées à la publication "supabase_realtime" (fait automatiquement
--      par ce script, à confirmer visuellement).

create extension if not exists "pgcrypto";

-- ========================================
-- TABLES
-- ========================================

create table public.centres (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  admin_id uuid not null references auth.users(id) on delete cascade,
  ville text not null default '',
  pays text not null default '',
  date_creation timestamptz not null default now(),
  actif boolean not null default true
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nom text not null default '',
  prenom text not null default '',
  email text not null default '',
  role text not null check (role in ('admin', 'formateur', 'apprenant')),
  centre_id uuid references public.centres(id) on delete set null,
  is_first_login boolean not null default false
);

create table public.formations (
  id uuid primary key default gen_random_uuid(),
  titre text not null default '',
  description text not null default '',
  formateur_id uuid references auth.users(id) on delete set null,
  formateur_nom text not null default '',
  nombre_sessions integer not null default 0,
  niveau text not null default 'Debutant',
  date_creation timestamptz not null default now(),
  date_debut timestamptz,
  date_fin timestamptz,
  centre_id uuid not null references public.centres(id) on delete cascade
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  formation_id uuid not null references public.formations(id) on delete cascade,
  centre_id uuid not null references public.centres(id) on delete cascade,
  titre text not null default '',
  details text not null default '',
  date timestamptz,
  heure_debut text not null default '',
  heure_fin text not null default '',
  salle text not null default '',
  statut text not null default 'planifiee' check (statut in ('planifiee', 'enCours', 'terminee'))
);

create table public.inscriptions (
  id uuid primary key default gen_random_uuid(),
  apprenant_id uuid not null references auth.users(id) on delete cascade,
  apprenant_nom text not null default '',
  formation_id uuid not null references public.formations(id) on delete cascade,
  centre_id uuid not null references public.centres(id) on delete cascade,
  date_inscription timestamptz not null default now(),
  statut text not null default 'enAttente' check (statut in ('enAttente', 'confirmee', 'annulee'))
);

create table public.presences (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  formation_id uuid not null references public.formations(id) on delete cascade,
  centre_id uuid not null references public.centres(id) on delete cascade,
  apprenant_id uuid not null references auth.users(id) on delete cascade,
  apprenant_nom text not null default '',
  present boolean not null default false,
  date timestamptz not null default now()
);

-- Debt de securite acceptee et documentee (voir README section 8) : cette
-- collection reste volontairement ouverte, comme sous Firestore. Le
-- Super Admin cree/liste/supprime des codes sans etre authentifie
-- (acces cache par geste dans l'app, pas par un compte). La lecture par
-- token depuis inscriptionAdmin() se fait elle aussi avant toute
-- authentification (le compte n'existe pas encore a ce moment-la).
create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  utilise boolean not null default false,
  date_creation timestamptz not null default now(),
  admin_id uuid references auth.users(id) on delete set null
);

-- ========================================
-- FONCTIONS HELPER (security definer pour eviter la recursion RLS sur profiles)
-- ========================================

create or replace function public.get_user_role()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.get_user_centre_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select centre_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null and public.get_user_role() = 'admin';
$$;

create or replace function public.is_formateur()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null and public.get_user_role() = 'formateur';
$$;

create or replace function public.is_apprenant()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null and public.get_user_role() = 'apprenant';
$$;

create or replace function public.is_user_in_centre(target_centre_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null and public.get_user_centre_id() = target_centre_id;
$$;

create or replace function public.is_owner_of_centre(target_centre_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_admin() and exists (
    select 1 from public.centres
    where id = target_centre_id and admin_id = auth.uid()
  );
$$;

-- Equivalent de la regle Firestore qui empeche un utilisateur de modifier
-- son propre role/centre_id via une mise a jour de son profil (seul l'admin
-- proprietaire du centre peut le faire).
create or replace function public.prevent_self_role_centre_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_owner_of_centre(old.centre_id) then
    if new.role is distinct from old.role or new.centre_id is distinct from old.centre_id then
      raise exception 'Modification du role ou du centre non autorisee';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_prevent_self_role_centre_change
  before update on public.profiles
  for each row
  execute function public.prevent_self_role_centre_change();

-- ========================================
-- RLS
-- ========================================

alter table public.centres enable row level security;
alter table public.profiles enable row level security;
alter table public.formations enable row level security;
alter table public.sessions enable row level security;
alter table public.inscriptions enable row level security;
alter table public.presences enable row level security;
alter table public.invitations enable row level security;

-- centres
create policy "centres_select" on public.centres for select
  using ((public.is_admin() and admin_id = auth.uid()) or public.is_user_in_centre(id));

create policy "centres_insert" on public.centres for insert
  with check (admin_id = auth.uid());

create policy "centres_update" on public.centres for update
  using (public.is_admin() and admin_id = auth.uid());

create policy "centres_delete" on public.centres for delete
  using (public.is_admin() and admin_id = auth.uid());

-- profiles
create policy "profiles_select" on public.profiles for select
  using (
    auth.uid() = id
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
    or (public.is_apprenant() and public.is_user_in_centre(centre_id))
  );

create policy "profiles_insert" on public.profiles for insert
  with check (
    auth.uid() = id
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
  );

create policy "profiles_update" on public.profiles for update
  using (
    auth.uid() = id
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
  );

create policy "profiles_delete" on public.profiles for delete
  using (public.is_admin() and public.is_owner_of_centre(centre_id));

-- formations
create policy "formations_select" on public.formations for select
  using (public.is_user_in_centre(centre_id) or (public.is_admin() and public.is_owner_of_centre(centre_id)));

create policy "formations_insert" on public.formations for insert
  with check (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "formations_update" on public.formations for update
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and formateur_id = auth.uid())
  );

create policy "formations_delete" on public.formations for delete
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and formateur_id = auth.uid())
  );

-- sessions
create policy "sessions_select" on public.sessions for select
  using (public.is_user_in_centre(centre_id) or (public.is_admin() and public.is_owner_of_centre(centre_id)));

create policy "sessions_insert" on public.sessions for insert
  with check (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "sessions_update" on public.sessions for update
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "sessions_delete" on public.sessions for delete
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

-- inscriptions
create policy "inscriptions_select" on public.inscriptions for select
  using (
    (public.is_apprenant() and apprenant_id = auth.uid())
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "inscriptions_insert" on public.inscriptions for insert
  with check (
    (public.is_apprenant() and apprenant_id = auth.uid() and public.is_user_in_centre(centre_id))
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "inscriptions_update" on public.inscriptions for update
  using (
    (public.is_apprenant() and apprenant_id = auth.uid())
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "inscriptions_delete" on public.inscriptions for delete
  using (
    (public.is_apprenant() and apprenant_id = auth.uid())
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

-- presences
create policy "presences_select" on public.presences for select
  using (
    (public.is_apprenant() and apprenant_id = auth.uid())
    or (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "presences_insert" on public.presences for insert
  with check (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "presences_update" on public.presences for update
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

create policy "presences_delete" on public.presences for delete
  using (
    (public.is_admin() and public.is_owner_of_centre(centre_id))
    or (public.is_formateur() and public.is_user_in_centre(centre_id))
  );

-- invitations : ouvert volontairement (dette acceptee, voir commentaire plus haut)
create policy "invitations_select" on public.invitations for select using (true);
create policy "invitations_insert" on public.invitations for insert with check (true);
create policy "invitations_update" on public.invitations for update using (true);
create policy "invitations_delete" on public.invitations for delete using (true);

-- ========================================
-- REALTIME
-- ========================================

alter publication supabase_realtime add table
  public.centres,
  public.profiles,
  public.formations,
  public.sessions,
  public.inscriptions,
  public.presences,
  public.invitations;
