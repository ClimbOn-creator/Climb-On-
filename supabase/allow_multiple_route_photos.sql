-- Allow every signed-in climber to add any number of recent pictures to a
-- route. Safe to run on databases that never had the legacy one-photo limit.

alter table public.route_photos
drop constraint if exists route_photos_user_id_route_id_key;

create index if not exists route_photos_route_created_idx
on public.route_photos (route_id, created_at desc);
