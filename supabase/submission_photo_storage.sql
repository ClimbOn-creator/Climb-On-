-- Run once in Supabase > SQL Editor to enable required Add-page pictures.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'submission-photos',
  'submission-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Submission pictures are public" on storage.objects;
create policy "Submission pictures are public"
on storage.objects for select
using (bucket_id = 'submission-photos');

drop policy if exists "Users upload submission pictures" on storage.objects;
create policy "Users upload submission pictures"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'submission-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users remove submission pictures" on storage.objects;
create policy "Users remove submission pictures"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'submission-photos'
  and owner_id = auth.uid()::text
);
