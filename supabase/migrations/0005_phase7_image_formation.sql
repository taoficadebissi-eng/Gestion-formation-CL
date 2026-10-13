-- Migration 0005 — Phase 7 : image de couverture d'une formation.
--
-- Bucket public (à la différence de "notes", une image de couverture n'a
-- rien de sensible — elle est affichée dans le catalogue, y compris pour
-- des rôles qui ne sont pas encore inscrits). URL publique stable, pas
-- besoin d'URL signée à la demande.
--
-- À exécuter après 0004_phase5_blocage.sql.

alter table public.formations
  add column image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'formations-images',
  'formations-images',
  true,
  5242880, -- 5 Mo
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

-- Lecture publique (bucket public, mais on définit quand même une policy
-- explicite plutôt que de s'appuyer sur le seul flag "public" du bucket).
create policy "formations_images_select" on storage.objects for select
  using (bucket_id = 'formations-images');

-- Écriture : formateur de la formation ou admin propriétaire du centre.
-- Chemin attendu : formations/{formationId}/cover_{fileId}.{ext}
create policy "formations_images_insert" on storage.objects for insert
  with check (
    bucket_id = 'formations-images'
    and (
      public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
      or public.is_admin_owner_de_formation(((storage.foldername(name))[2])::uuid)
    )
  );

create policy "formations_images_delete" on storage.objects for delete
  using (
    bucket_id = 'formations-images'
    and (
      public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
      or public.is_admin_owner_de_formation(((storage.foldername(name))[2])::uuid)
    )
  );
