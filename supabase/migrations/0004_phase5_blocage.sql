-- Migration 0004 — Phase 5 : restriction d'accès (notes + chat de groupe)
-- quand le statut de paiement d'un apprenant est "bloque", pour la
-- formation concernée. Vérification côté RLS (pas seulement côté UI),
-- comme l'exige le cahier des charges.
--
-- À exécuter après 0003_phase3_storage.sql.

create or replace function public.apprenant_bloque_pour_formation(target_formation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.inscriptions
    where formation_id = target_formation_id
      and apprenant_id = auth.uid()
      and statut_paiement = 'bloque'
  );
$$;

-- notes (table) : un apprenant bloqué ne voit plus les notes de cette
-- formation. Le formateur et l'admin ne sont jamais concernés.
drop policy if exists "notes_select" on public.notes;
create policy "notes_select" on public.notes for select
  using (
    (
      public.is_inscrit_formation(formation_id)
      and not public.apprenant_bloque_pour_formation(formation_id)
    )
    or public.is_formateur_de_formation(formation_id)
    or public.is_admin_owner_de_formation(formation_id)
  );

-- notes (Storage) : même règle pour le téléchargement direct du fichier.
drop policy if exists "notes_storage_select" on storage.objects;
create policy "notes_storage_select" on storage.objects for select
  using (
    bucket_id = 'notes'
    and (
      (
        public.is_inscrit_formation(((storage.foldername(name))[2])::uuid)
        and not public.apprenant_bloque_pour_formation(((storage.foldername(name))[2])::uuid)
      )
      or public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
      or public.is_admin_owner_de_formation(((storage.foldername(name))[2])::uuid)
    )
  );

-- messages (chat de groupe) : lecture ET écriture bloquées pour l'apprenant
-- concerné, sur cette formation.
drop policy if exists "messages_select" on public.messages;
create policy "messages_select" on public.messages for select
  using (
    (
      public.is_inscrit_formation(formation_id)
      and not public.apprenant_bloque_pour_formation(formation_id)
    )
    or public.is_formateur_de_formation(formation_id)
    or public.is_admin_owner_de_formation(formation_id)
  );

drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages for insert
  with check (
    auteur_id = auth.uid()
    and (
      (
        public.is_inscrit_formation(formation_id)
        and not public.apprenant_bloque_pour_formation(formation_id)
      )
      or public.is_formateur_de_formation(formation_id)
      or public.is_admin_owner_de_formation(formation_id)
    )
  );
