-- Creator-managed catalogue and background pictures.
-- Run after admin_catalog_route_editor.sql so is_app_admin() and the
-- submission-photos storage bucket are available.

create table if not exists public.app_visuals (
  visual_key text primary key,
  image_url text not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.app_visuals enable row level security;

drop policy if exists "App visuals are publicly readable" on public.app_visuals;
create policy "App visuals are publicly readable"
on public.app_visuals for select
using (true);

insert into public.app_visuals (visual_key, image_url) values
  ('side_banner_left', 'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5'),
  ('side_banner_right', 'https://images.unsplash.com/photo-1519681393784-d120267933ba'),
  ('default_crag', 'https://images.unsplash.com/photo-1522163182402-834f871fd851'),
  ('range_canadian-rockies', 'https://images.unsplash.com/photo-1500534623283-312aade485b7'),
  ('range_cariboo', 'https://images.unsplash.com/photo-1464278533981-50106e6176b1'),
  ('range_selkirk', 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'),
  ('range_monashee', 'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5'),
  ('range_purcell', 'https://images.unsplash.com/photo-1519681393784-d120267933ba'),
  ('range_hart', 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e'),
  ('range_muskwa', 'https://images.unsplash.com/photo-1464278533981-50106e6176b1'),
  ('range_coast-range', 'https://images.unsplash.com/photo-1522163182402-834f871fd851')
on conflict (visual_key) do nothing;

create or replace function public.app_visual_catalog()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_object_agg(visual_key, image_url), '{}'::jsonb)
  from public.app_visuals;
$$;

create or replace function public.admin_update_app_visual(
  target_visual_key text,
  new_image_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  if target_visual_key not in (
    'side_banner_left',
    'side_banner_right',
    'default_crag',
    'range_canadian-rockies',
    'range_cariboo',
    'range_selkirk',
    'range_monashee',
    'range_purcell',
    'range_hart',
    'range_muskwa',
    'range_coast-range'
  ) then
    raise exception 'Unknown app visual';
  end if;
  if trim(new_image_url) = '' then raise exception 'Picture is required'; end if;

  insert into public.app_visuals (
    visual_key, image_url, updated_by, updated_at
  ) values (
    target_visual_key, trim(new_image_url), auth.uid(), now()
  )
  on conflict (visual_key) do update set
    image_url = excluded.image_url,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.app_visual_catalog() to anon, authenticated;
grant execute on function public.admin_update_app_visual(text, text)
to authenticated;
