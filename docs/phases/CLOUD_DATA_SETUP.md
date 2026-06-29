# Cloud Data Setup

The app now uses one catalog/data path:

1. Supabase `climb_catalog()` when Supabase is configured.
2. Cached catalog on the device when offline.
3. Local sample data only as a final fallback.

User actions are saved locally first for speed, then synced to Supabase when a user is signed in.

Cloud-backed tables added in `supabase/schema.sql`:

- `user_sends`
- `route_attempts`
- `route_grade_opinions`
- `route_comments`
- `route_photos`
- `user_projects`

Run `supabase/schema.sql` in Supabase SQL editor after creating the project. Then seed real crags, walls, and routes into `crags`, `walls`, and `routes`.

The app reads real route data from:

```sql
select public.climb_catalog();
```

After Supabase and Google Auth are configured, route sends, attempts, comments, photos, grade opinions, and projects will sync to the signed-in user's cloud account while still being remembered locally on the device.
