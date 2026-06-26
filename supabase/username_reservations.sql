-- Run once in Supabase > SQL Editor.
-- Usernames are permanent: changing a username does not release the old one.

create table if not exists public.username_reservations (
  username text primary key,
  user_id uuid not null,
  claimed_at timestamptz not null default now(),
  constraint username_reservations_format check (
    username ~ '^[a-z0-9_]{3,24}$'
  )
);

alter table public.username_reservations enable row level security;
revoke all on public.username_reservations from anon, authenticated;

insert into public.username_reservations (username, user_id)
select lower(username), id
from public.profiles
where username is not null
  and lower(username) ~ '^[a-z0-9_]{3,24}$'
on conflict (username) do nothing;

create or replace function public.normalize_username(candidate text)
returns text
language sql
immutable
set search_path = public
as $$
  select lower(regexp_replace(trim(coalesce(candidate, '')), '[^a-z0-9_]+', '_', 'g'));
$$;

create or replace function public.reserve_profile_username()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized text;
  owner_id uuid;
begin
  normalized := public.normalize_username(new.username);

  if normalized !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Username must be 3 to 24 letters, numbers, or underscores.'
      using errcode = '22023';
  end if;

  insert into public.username_reservations (username, user_id)
  values (normalized, new.id)
  on conflict (username) do nothing;

  select user_id into owner_id
  from public.username_reservations
  where username = normalized;

  if owner_id is distinct from new.id then
    raise exception 'That username is already reserved.'
      using errcode = '23505';
  end if;

  new.username := normalized;
  return new;
end;
$$;

drop trigger if exists reserve_profile_username_trigger on public.profiles;
create trigger reserve_profile_username_trigger
before insert or update of username on public.profiles
for each row execute function public.reserve_profile_username();

create or replace function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.normalize_username(candidate) ~ '^[a-z0-9_]{3,24}$'
    and not exists (
      select 1
      from public.username_reservations
      where username = public.normalize_username(candidate)
        and user_id is distinct from auth.uid()
    );
$$;

revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to authenticated;
