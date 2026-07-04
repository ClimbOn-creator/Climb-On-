-- Preserve an offline-recorded approach when its owner later submits a new
-- public crag and route for community review.

alter table public.route_submissions
add column if not exists approach_path_points jsonb;

alter table public.route_submissions
add column if not exists approach_distance_meters double precision;
