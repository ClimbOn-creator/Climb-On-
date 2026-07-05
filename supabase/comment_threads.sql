-- Nested route comment discussions with attributed authors.
-- Run after schema.sql and profile setup. Safe to run more than once.

alter table public.route_comments
add column if not exists parent_comment_id uuid references public.route_comments(id) on delete cascade;

create index if not exists route_comments_parent_created_idx
on public.route_comments (parent_comment_id, created_at asc);

drop function if exists public.route_comments_with_authors(uuid);

create function public.route_comments_with_authors(
  target_route_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  route_id uuid,
  parent_comment_id uuid,
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
    comments.parent_comment_id,
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
  order by
    case when comments.parent_comment_id is null then comments.created_at end desc,
    comments.created_at asc;
$$;

revoke all on function public.route_comments_with_authors(uuid) from public;
grant execute on function public.route_comments_with_authors(uuid) to anon, authenticated;
