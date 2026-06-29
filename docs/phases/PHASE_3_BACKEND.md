# Phase 3 Backend Start

Use Supabase with Postgres and PostGIS.

What was added:

- `supabase/schema.sql`: first database schema, indexes, RLS policies, and location RPC functions.
- `lib/config/supabase_config.dart`: reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `--dart-define`.
- `lib/services/database_service.dart`: app-facing methods for map bounds and route search.
- `lib/services/auth_service.dart`: Google sign-in/sign-out entry points.
- `DATA_ENTRY_GUIDE.md`: where to type crags/walls/routes before Supabase is live.
- `supabase/seed_victoria_example.sql`: example SQL seed shape.

Run the app later with:

```sh
flutter run \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

The map should eventually call `loadCragsInBounds(...)` whenever the viewport changes. That is how the app avoids loading 100,000+ crags at once.

## What Still Requires Your Supabase Dashboard

Codex cannot complete these without your project credentials:

- Create the Supabase project.
- Run `supabase/schema.sql` in the SQL editor.
- Enable Google OAuth in Supabase Auth.
- Add iOS/Android redirect URLs.
- Run the app with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
