# Phase 6 Profile And Progression

Goal: make the profile feel like a climbing logbook.

What was added:

- Google sign-in is wired through `AuthService` and guarded when Supabase credentials are missing.
- Profile stats update from completed sends, attempts, and saved projects.
- Completed routes list.
- Tick list from saved project routes.
- Hardest send calculation.
- Grade pyramid from completed routes.
- Climbing style breakdown.
- Areas climbed from completed route crags.
- Recent activity from sends and attempts.
- Private/public profile toggle.

## Auth Setup Still Needed

The app code can start Google OAuth once Supabase is configured. The remaining work is in your Supabase dashboard:

- Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` at run/build time.
- Enable Google as an Auth provider.
- Add web and mobile redirect URLs.
- Add the app domain to the OAuth allowlist.

## Next Phase

Phase 7 should turn search into a real route discovery surface with filters for grade, style, pitch type, area, distance, and project/sent status.
