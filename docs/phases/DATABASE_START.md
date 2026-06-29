# Climb On Database Start

Use Supabase as the first real backend:

- Supabase Auth gives secure login and Google sign-in.
- Supabase uses Postgres, which can later use PostGIS for map/location searches.
- User route completion should live in the database, not only in Flutter memory.

## Where To Add Crags And Routes Right Now

Until the backend is connected, add Victoria crags and routes in:

`lib/crags.dart`

Each `Crag` has:

- `name`
- `location`
- `parking`
- `walls`

Each `RouteInfo` has:

- `name`
- `grade`
- `rating`
- `location`, which is the exact wall/route GPS point
- `description`
- `approachNotes`
- `dangerInfo`
- `recentAscents`
- `bolts`
- `routeLength`
- `ropeLength`
- `topRope`

## First Tables To Create In Supabase

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

create table crags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  parking_latitude double precision,
  parking_longitude double precision,
  region text,
  created_at timestamptz default now()
);

create table walls (
  id uuid primary key default gen_random_uuid(),
  crag_id uuid references crags(id) on delete cascade,
  name text not null
);

create table routes (
  id uuid primary key default gen_random_uuid(),
  wall_id uuid references walls(id) on delete cascade,
  name text not null,
  grade text,
  rating double precision,
  latitude double precision,
  longitude double precision,
  description text,
  approach_notes text,
  danger_info text,
  route_type text,
  angle text,
  bolts integer,
  route_length integer,
  rope_length integer,
  top_rope boolean default false
);

create table user_sends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  route_id uuid references routes(id) on delete cascade,
  style text,
  sent_at timestamptz default now(),
  unique (user_id, route_id)
);
```

## Security Rule

Turn on row-level security. Users should only be able to insert, update, or delete their own `user_sends`.

Crag and route data can be public read-only at first, then later you can add admin/moderator tools.
