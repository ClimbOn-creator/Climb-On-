-- Allows the public app key to read the climb catalog tables used by
-- public.climb_catalog(). This does not open private user logbook tables.

grant usage on schema public to anon, authenticated;
grant select on public.crags to anon, authenticated;
grant select on public.walls to anon, authenticated;
grant select on public.routes to anon, authenticated;
grant execute on function public.climb_catalog() to anon, authenticated;

drop policy if exists "Crags are publicly readable" on public.crags;
create policy "Crags are publicly readable"
on public.crags for select
using (true);

drop policy if exists "Walls are publicly readable" on public.walls;
create policy "Walls are publicly readable"
on public.walls for select
using (true);

drop policy if exists "Routes are publicly readable" on public.routes;
create policy "Routes are publicly readable"
on public.routes for select
using (true);

select
  (select count(*) from public.crags) as crags,
  (select count(*) from public.walls) as walls,
  (select count(*) from public.routes) as routes,
  exists(select 1 from public.crags where name = 'Cyberia') as has_cyberia,
  exists(select 1 from public.routes where name = 'Turing Test') as has_turing_test;

