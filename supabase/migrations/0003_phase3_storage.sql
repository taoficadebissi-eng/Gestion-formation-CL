-- Migration 0003 — Phase 3 : bucket Supabase Storage pour les notes de
-- cours, + policies sur storage.objects.
--
-- Convention de chemin : formations/{formationId}/notes/{fileId}_{nomFichier}
-- (fileId = uuid généré côté client à l'upload, pour éviter les collisions
-- de nom de fichier).
--
-- À exécuter dans Supabase Dashboard > SQL Editor, après 0002_phase2.sql.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'notes',
  'notes',
  false,
  20971520, -- 20 Mo
  array[
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do nothing;

-- Lecture : apprenant inscrit à la formation, formateur de la formation,
-- ou admin propriétaire du centre — même logique que la table `notes`
-- (0002_phase2.sql). Le formationId est déduit du chemin de l'objet :
-- storage.foldername('formations/<id>/notes/<fichier>') = {formations, <id>, notes}.
create policy "notes_storage_select" on storage.objects for select
  using (
    bucket_id = 'notes'
    and (
      public.is_inscrit_formation(((storage.foldername(name))[2])::uuid)
      or public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
      or public.is_admin_owner_de_formation(((storage.foldername(name))[2])::uuid)
    )
  );

-- Écriture (upload) : réservée au formateur de la formation concernée.
create policy "notes_storage_insert" on storage.objects for insert
  with check (
    bucket_id = 'notes'
    and public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
  );

-- Suppression : réservée au formateur de la formation concernée.
create policy "notes_storage_delete" on storage.objects for delete
  using (
    bucket_id = 'notes'
    and public.is_formateur_de_formation(((storage.foldername(name))[2])::uuid)
  );
