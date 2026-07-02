-- Run once in Supabase > SQL Editor to enable real friends and social activity.

create table if not exists public.user_friends (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  constraint user_friends_not_self check (user_id <> friend_id)
);

alter table public.user_friends enable row level security;

drop policy if exists "Users read own friends" on public.user_friends;
create policy "Users read own friends"
on public.user_friends for select
using (auth.uid() = user_id);

drop policy if exists "Users add own friends" on public.user_friends;
create policy "Users add own friends"
on public.user_friends for insert
with check (auth.uid() = user_id);

drop policy if exists "Users remove own friends" on public.user_friends;
create policy "Users remove own friends"
on public.user_friends for delete
using (auth.uid() = user_id);

create or replace function public.search_climbers(search_text text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  home_area text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    profiles.id,
    coalesce(profiles.username, ''),
    coalesce(profiles.display_name, ''),
    coalesce(profiles.avatar_url, ''),
    coalesce(profiles.bio, ''),
    coalesce(profiles.home_area, '')
  from public.profiles
  where profiles.id <> auth.uid()
    and profiles.is_public = true
    and (
      profiles.username ilike '%' || search_text || '%'
      or profiles.display_name ilike '%' || search_text || '%'
    )
  order by profiles.username
  limit 20;
$$;

create or replace function public.my_friends()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  home_area text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    profiles.id,
    coalesce(profiles.username, ''),
    coalesce(profiles.display_name, ''),
    coalesce(profiles.avatar_url, ''),
    coalesce(profiles.bio, ''),
    coalesce(profiles.home_area, '')
  from public.user_friends
  join public.profiles on profiles.id = user_friends.friend_id
  where user_friends.user_id = auth.uid()
  order by profiles.username;
$$;

create or replace function public.friend_send_feed()
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  home_area text,
  route_id uuid,
  grade text,
  style text,
  sent_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    profiles.id,
    coalesce(profiles.username, ''),
    coalesce(profiles.display_name, ''),
    coalesce(profiles.avatar_url, ''),
    coalesce(profiles.bio, ''),
    coalesce(profiles.home_area, ''),
    sends.route_id,
    coalesce(routes.grade, ''),
    coalesce(sends.style, 'Redpoint'),
    sends.sent_at
  from public.user_friends
  join public.user_sends as sends on sends.user_id = user_friends.friend_id
  join public.profiles on profiles.id = sends.user_id
  join public.routes on routes.id = sends.route_id
  where user_friends.user_id = auth.uid()
  order by sends.sent_at desc
  limit 20;
$$;

create or replace function public.my_recent_comments()
returns table (
  id uuid,
  route_id uuid,
  route_name text,
  body text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    comments.id,
    comments.route_id,
    routes.name,
    comments.body,
    comments.created_at
  from public.route_comments as comments
  join public.routes on routes.id = comments.route_id
  where comments.user_id = auth.uid()
  order by comments.created_at desc
  limit 10;
$$;

revoke all on function public.search_climbers(text) from public;
revoke all on function public.my_friends() from public;
revoke all on function public.friend_send_feed() from public;
revoke all on function public.my_recent_comments() from public;

grant execute on function public.search_climbers(text) to authenticated;
grant execute on function public.my_friends() to authenticated;
grant execute on function public.friend_send_feed() to authenticated;
grant execute on function public.my_recent_comments() to authenticated;
