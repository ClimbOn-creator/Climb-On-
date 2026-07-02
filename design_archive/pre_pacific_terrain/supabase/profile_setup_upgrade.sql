-- Profile setup fields for Google sign-in onboarding.

alter table public.profiles
  add column if not exists username text,
  add column if not exists home_area text default '',
  add column if not exists climbing_style text default '',
  add column if not exists is_public boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists profiles_username_unique
on public.profiles (lower(username))
where username is not null and username <> '';

alter table public.profiles enable row level security;

drop policy if exists "Profiles are readable" on public.profiles;
create policy "Profiles are readable"
on public.profiles for select
using (is_public = true or auth.uid() = id);

drop policy if exists "Users manage own profile" on public.profiles;
create policy "Users manage own profile"
on public.profiles for all
using (auth.uid() = id)
with check (auth.uid() = id);

grant select, insert, update on public.profiles to authenticated;

