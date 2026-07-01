# Supabase Setup

Run SQL in a development project first. Keep production changes reviewed through
GitHub before applying them in the Supabase SQL Editor.

## Fresh project order

1. `schema.sql`
2. `profile_setup_upgrade.sql`
3. `username_reservations.sql`
4. `migration_safe_phase_cloud.sql`
5. `ski_routes_seed.sql`
6. `admin_map_editor_setup.sql`
7. `map_paths_setup.sql`
8. `profile_avatar_storage.sql`
9. `route_photo_storage.sql`
10. `submission_photo_storage.sql`
11. `comment_profiles_and_known_walls.sql`
12. `social_friends.sql`
13. `creator_warnings_and_gps_recordings.sql`
14. `fix_public_climb_catalog_access.sql`
15. `add_chosslandia_crag.sql`
16. `admin_catalog_route_editor.sql`
17. `admin_ski_route_editor.sql`
18. `vancouver_island_ski_catalog.sql`
19. `route_trailhead_images.sql`
20. `offline_map_regions.sql`

Optional catalog data:

- `seed_victoria_example.sql`: small example catalog.
- `seed_greater_victoria_bouldering_pdf.sql`: large Victoria bouldering catalog.

Use `check_climb_catalog_counts.sql` after setup. Use
`check_and_add_admin_user.sql` only when intentionally granting an administrator.

## Production safety

- Back up the database before schema changes.
- Test every script in development.
- Never put the Supabase service-role key in the Flutter app or GitHub.
- The publishable/anon key is the only Supabase key intended for the client.
- Preserve `created_by` when approving user-created catalog content.
