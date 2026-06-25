select
  (select count(*) from public.crags) as crags,
  (select count(*) from public.walls) as walls,
  (select count(*) from public.routes) as routes,
  exists(select 1 from public.crags where name = 'Cyberia') as has_cyberia,
  exists(select 1 from public.routes where name = 'Turing Test') as has_turing_test;

