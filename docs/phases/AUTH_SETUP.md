# Auth Setup

The app-side Google OAuth setup is wired for Supabase.

## App Redirect URL

Use this callback URL for native Android and iOS builds:

```text
climbon://login-callback
```

For hosted web builds, also add your hosted app URL:

```text
https://your-site.netlify.app
```

If Supabase asks for an exact callback URL for web, use:

```text
https://your-site.netlify.app
```

## Build With Supabase

Run locally:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-or-anon-key \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=climbon://login-callback
```

Build web:

```sh
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-or-anon-key \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=https://your-site.netlify.app
```

For native iOS/Android builds, keep:

```text
SUPABASE_AUTH_REDIRECT_URL=climbon://login-callback
```

## Supabase Dashboard Checklist

In Supabase:

- Go to Authentication -> Providers -> Google.
- Enable Google.
- Paste the Google OAuth Client ID and Client Secret.
- Go to Authentication -> URL Configuration.
- Add `climbon://login-callback` to redirect URLs.
- Add your hosted web app URL to redirect URLs.
- Set Site URL to your hosted web app URL.

## Google Cloud Checklist

In Google Cloud OAuth settings:

- Add the Supabase callback URL shown in the Supabase Google provider panel.
- Add your hosted web app domain to authorized JavaScript origins.

The exact Supabase callback usually looks like:

```text
https://your-project-ref.supabase.co/auth/v1/callback
```
