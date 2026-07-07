# Climb On

Climb On is a Flutter climbing app for finding nearby crags, browsing routes, saving sends, and sharing parking coordinates.

## Current App

- Map view with crag markers, route filters, parking markers, and shareable GPS coordinates.
- Crag browser with walls, route lists, access notes, approach notes, and danger notes.
- Route feed with search, route detail sheets, comments, and completed-route logging.
- Profile screen with recent sends.
- Supabase-ready backend layer for future live crag, wall, route, and auth data.
- Mobile-ready navigation and install metadata for web, Android, and iOS.

## Run Locally

```sh
flutter pub get
flutter run
```

With Supabase:

```sh
flutter run \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=climbon://login-callback
```

Route photos, profile avatars, submission photos, and app visuals use Supabase
Storage by default. To move bulky media to R2/S3-compatible storage later, point
the app at a small private upload gateway:

```sh
flutter run \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
  --dart-define=OBJECT_STORAGE_UPLOAD_ENDPOINT=https://api.your-domain.ca/storage/upload \
  --dart-define=OBJECT_STORAGE_DELETE_ENDPOINT=https://api.your-domain.ca/storage/delete \
  --dart-define=OBJECT_STORAGE_PUBLIC_BASE_URL=https://media.your-domain.ca
```

The gateway should accept multipart uploads with `area`, `path`, `upsert`, and
`file` fields, then return JSON containing the public `url` and stored `path`.
Do not put R2/S3 secret keys in the Flutter app.

See [`docs/phases/AUTH_SETUP.md`](docs/phases/AUTH_SETUP.md) for Google sign-in
redirect URLs and dashboard setup.

## Get It On Your Phone

### Fastest: install the web app

Build it:

```sh
flutter build web --release
```

Host the `build/web` folder on any HTTPS host, such as Cloudflare Pages, Firebase Hosting, Netlify, Vercel, or GitHub Pages. For the easiest upload, run:

```sh
./scripts/package_web_upload.sh
```

Then upload `climb_on_web_upload.zip`.

For Cloudflare Pages connected directly to GitHub, use:

```sh
./scripts/cloudflare_build.sh
```

as the build command, with `build/web` as the build output directory.

For Google sign-in on web, build with your hosted URL as the redirect:

```sh
flutter build web --release \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=https://your-site.netlify.app
```

Then on your phone:

- iPhone: open the site in Safari, tap Share, then tap Add to Home Screen.
- Android: open the site in Chrome, tap the menu, then tap Install app or Add to Home screen.

This is the easiest path because it does not require App Store review.

### Android: make an APK

```sh
flutter build apk --release
```

The installable file will be at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

You can send that APK to an Android phone and install it after allowing installs from that source. Before publishing to Google Play, replace the debug signing setup in `android/app/build.gradle.kts` with a private release key.

### iPhone: run through Xcode or TestFlight

For your own iPhone during development:

```sh
flutter build ios --release
open ios/Runner.xcworkspace
```

In Xcode, choose your Apple developer team, plug in your iPhone, and press Run.

For other testers, archive the app in Xcode and upload it to App Store Connect for TestFlight. This requires an Apple Developer Program account.

## Shipping Guide

See [`docs/phases/SHIPPING_GUIDE.md`](docs/phases/SHIPPING_GUIDE.md) for the
step-by-step shipping path.

## Backend Setup

Start with [`docs/EMPLOYEE_HANDOFF.md`](docs/EMPLOYEE_HANDOFF.md). Database setup
order is documented in [`supabase/README.md`](supabase/README.md); historical
phase notes remain under [`docs/phases/`](docs/phases/).

## Offline BC maps

The app supports six downloadable BC sections using a self-hosted open-data map
stack. See [`docs/offline_maps.md`](docs/offline_maps.md) for the Protomaps,
terrain, Sentinel-2, and Cloudflare R2 setup.
