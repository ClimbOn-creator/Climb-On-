-- Run once in Supabase > SQL Editor for attributed comments and known-wall tags.

alter table public.route_submissions
add column if not exists crag_id uuid references public.crags(id) on delete set null;

alter table public.route_submissions
add column if not exists wall_id uuid references public.walls(id) on delete set null;

-- Comments already reference auth.users and profiles use that same user id.
-- These indexes keep route comment refreshes and profile attribution quick.
create index if not exists route_comments_route_created_idx
on public.route_comments (route_id, created_at desc);

create index if not exists route_submissions_known_location_idx
on public.route_submissions (crag_id, wall_id);

create or replace function public.route_comments_with_authors(
  target_route_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  route_id uuid,
  body text,
  created_at timestamptz,
  author_username text,
  author_display_name text,
  author_avatar_url text,
  author_bio text,
  author_home_area text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    comments.id,
    comments.user_id,
    comments.route_id,
    comments.body,
    comments.created_at,
    coalesce(profiles.username, ''),
    coalesce(profiles.display_name, ''),
    coalesce(profiles.avatar_url, ''),
    case when profiles.is_public then coalesce(profiles.bio, '') else '' end,
    case when profiles.is_public then coalesce(profiles.home_area, '') else '' end
  from public.route_comments as comments
  left join public.profiles as profiles on profiles.id = comments.user_id
  where comments.route_id = target_route_id
  order by comments.created_at desc;
$$;

revoke all on function public.route_comments_with_authors(uuid) from public;
grant execute on function public.route_comments_with_authors(uuid) to anon, authenticated;
