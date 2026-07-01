# Climb On Employee Handoff

## Where the project lives

GitHub should be the shared source of truth. Use a private GitHub repository and
invite the employee as a collaborator. Do not send ZIP snapshots back and forth;
they become stale and make it unclear which version is current.

Never commit `.env`, `.env.local.json`, production keys, signing certificates, or
Apple/Google credentials. Share those through a password manager.

## First-day setup

1. Install Flutter using the version compatible with `pubspec.yaml`.
2. Clone the GitHub repository.
3. Run `flutter pub get`.
4. Copy `supabase.env.example` to a local ignored environment file and add the
   development Supabase URL and publishable key.
5. Follow [../supabase/README.md](../supabase/README.md) for database setup.
6. Run `flutter analyze`, `flutter test`, and `flutter build web`.

## Repository map

- `lib/models/`: app data shapes.
- `lib/services/`: Supabase, authentication, map, and profile operations.
- `lib/state/`: Riverpod application state.
- `lib/screens/`: full app pages.
- `lib/widgets/`: reusable interface components.
- `supabase/`: schema, feature migrations, policies, and seed data.
- `test/`: automated tests.
- `scripts/`: repeatable build/package commands.
- `map_service/`: self-hosted Cloudflare service for legal offline map tiles.
- `docs/`: handoff and historical implementation notes.

The local `Full Zipped ` folder contains old build snapshots. It is intentionally
ignored by Git and is not part of the employee handoff.

## GitHub workflow

1. Pull the latest `main` before starting work.
2. Create a branch such as `codex/gps-recording` or `feature/gps-recording`.
3. Make one focused change per branch.
4. Run analysis, tests, and the relevant build.
5. Open a pull request and describe UI changes plus any SQL file that must run.
6. Review and merge into `main`; deploy from `main` only.

Protect `main` in GitHub and require pull requests. Keep production Supabase SQL
changes reviewed and recorded in this repository before running them.

## Current ownership rules

- A route/crag creator can edit its safety warning when `created_by` matches the
  signed-in profile.
- Route photos can only be removed by their uploader.
- GPS recordings belong to their recorder and enter review as `pending`.
- When approving a route or crag submission, copy its `user_id` into the final
  catalog row's `created_by` column. Without that step, creator editing is not
  intentionally granted.

## GPS recording workflow

1. Sign in and open Map.
2. Select a crag for a climbing approach, or select a ski tour.
3. Tap **Record GPS trail**. Ski mode asks for ascent or descent.
4. Keep the Map screen open while moving; points are sampled at least 3 metres
   apart and readings worse than 50 metres accuracy are ignored.
5. Stop, review distance and point count, then submit for review.
6. An administrator reviews `public.recorded_paths` and approves a safe line with
   `select public.admin_approve_recorded_path('recording-uuid');`. Approval copies
   it into the public crag/ski path fields.

GPS recordings are suggestions, not instant public edits. That keeps unsafe or
accidental tracks out of the shared database.
