# Storage architecture

Climb On keeps relational app data in Supabase and keeps large binary objects in
object storage. This lets the app grow route photos, profile pictures,
submission photos, app visuals, and offline map packs without bloating the
Postgres database.

## Default mode

Without extra build values, the app uploads media to the existing Supabase
Storage buckets:

- `route-photos`
- `profile-avatars`
- `submission-photos`

App visuals reuse `submission-photos` for backward compatibility with the
current SQL setup.

## External media mode

Set these build values to upload app media through an external gateway:

```text
OBJECT_STORAGE_UPLOAD_ENDPOINT=https://api.your-domain.ca/storage/upload
OBJECT_STORAGE_DELETE_ENDPOINT=https://api.your-domain.ca/storage/delete
OBJECT_STORAGE_PUBLIC_BASE_URL=https://media.your-domain.ca
```

The Flutter app sends a multipart `POST` to `OBJECT_STORAGE_UPLOAD_ENDPOINT`.
The request contains:

- `area`: one of `route-photos`, `profile-avatars`, `submission-photos`,
  `app-visuals`, or `offline-map-packs`
- `path`: the app-generated object path
- `upsert`: `true` or `false`
- `file`: the uploaded file bytes

The gateway must store the file in R2, S3, B2, MinIO, or another object store
and return JSON:

```json
{
  "path": "user-id/route-id/file.jpg",
  "url": "https://media.your-domain.ca/user-id/route-id/file.jpg"
}
```

If `url` is omitted, the app derives it from `OBJECT_STORAGE_PUBLIC_BASE_URL`
and the returned `path`.

Deletes are sent as JSON to `OBJECT_STORAGE_DELETE_ENDPOINT`:

```json
{
  "area": "route-photos",
  "paths": ["user-id/route-id/file.jpg"]
}
```

Keep object-storage credentials only on the gateway/server side. Never put R2,
S3, or service-role keys in the Flutter app.

## Image-cost controls

The app reduces image cost before and after upload:

- User route and submission pictures are picked at 1600 px max width and about
  78% quality.
- Profile avatars are picked at 512 px max width and about 72% quality.
- Admin/app visuals are capped to display-friendly sizes rather than full
  phone-camera originals.
- Cloudinary URLs are requested with `f_auto` and `q_auto` transformations for
  avatars, thumbnails, cards, detail views, and offline caches.
- Unknown storage URLs are left unchanged, so Supabase and future custom media
  URLs keep working until their own transformation support is added.

This avoids storing and repeatedly delivering giant original photos while still
keeping route pages sharp enough for real use.

## Offline map packs

Offline map packs are handled by `map_service/` and the scripts documented in
`docs/offline_maps.md`. Those archives belong in Cloudflare R2 or equivalent
object storage and are served through the map Worker, not through Supabase.
