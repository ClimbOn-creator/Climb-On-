-- After you sign in with Google once, find your UUID in Supabase:
-- Authentication > Users > click your user > copy User UID.
--
-- Then replace YOUR-USER-UUID-HERE below and run this.

insert into public.app_admins (user_id)
values ('519cee87-e5fb-4374-a61b-5dd45d912c81')
on conflict (user_id) do nothing;

select
  app_admins.user_id,
  users.email,
  app_admins.created_at
from public.app_admins
left join auth.users on users.id = app_admins.user_id;
