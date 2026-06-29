# Phase 5 Feed And Social Layer

Goal: make the feed useful, not just pretty.

What was added:

- Feed sections for friends' sends, your recent sends, routes near you, recommended projects, new routes nearby, and popular climbs this week.
- Search remains pinned at the top of the feed.
- Route actions for marking a send, adding an attempt, adding a grade opinion, adding a comment, adding a photo URL, saving a project, and sharing a route.
- Local state for attempts, grade opinions, comments, photos, projects, and completed sends.
- Completed sends still persist locally and are ready to become real database `Send` records later.

## Current Data Source

The feed is powered by the local sample crag data for now. Friend sends, nearby routes, new routes, and popular routes are derived from the current route catalog so the UI can be tested before Supabase is connected.

## Database Handoff

Later, these local actions should map to Supabase tables:

- completed route: `user_sends`
- attempt: `route_attempts`
- grade opinion: `route_grade_opinions`
- comment: `comments`
- photo: `route_photos`
- project save: `user_projects`
- share route: native share only, no database write required
