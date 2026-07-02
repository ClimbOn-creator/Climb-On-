-- Run once in Supabase > SQL Editor to enable shared route picture uploads.

alter table public.route_photos
add column if not exists storage_path text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'route-photos',
  'route-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Route pictures are public" on storage.objects;
create policy "Route pictures are public"
on storage.objects for select
using (bucket_id = 'route-photos');

drop policy if exists "Users upload route pictures" on storage.objects;
create policy "Users upload route pictures"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'route-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Creators remove route pictures" on storage.objects;
create policy "Creators remove route pictures"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'route-photos'
  and owner_id = auth.uid()::text
  and (storage.foldername(name))[1] = auth.uid()::text
);
