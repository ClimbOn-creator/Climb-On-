# Public Climb Submissions

The app has an Add tab where people can submit climbs for review.

The Add tab changes with the Climb/Ski mode switch:

- Climb mode submits climbs to `route_submissions`.
- Ski mode submits ski tours to `ski_route_submissions`.

Required fields:

- Submitter name
- Crag name
- Wall or sector name
- Route name
- Grade
- Route type
- Pitch type
- Wall angle
- Bolts
- Height
- Route length
- Rope length needed
- Top rope access
- GPS latitude
- GPS longitude
- Picture URL
- Description
- Approach notes
- Descent notes
- Danger/safety notes
- Gear notes

Submissions go into `public.route_submissions` with `status = 'pending'`.

Run the updated `supabase/migration_safe_phase_cloud.sql` in Supabase so the table and policies exist.

For safety, public submissions do not directly publish into `crags`, `walls`, or `routes`. Review them in Supabase first, then copy approved entries into the real catalog tables or build an approval screen later.

Ski tour submissions are also review-only. Review them in `ski_route_submissions`, then approve into `ski_routes`.
