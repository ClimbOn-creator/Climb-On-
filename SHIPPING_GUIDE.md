# Climb On Shipping Guide

This is the simple path for running Climb On as a website, an installable phone web app, and later as real iOS and Android store apps.

## 1. Website And Phone Install

Use this first. It is the fastest and cheapest way to get Climb On on phones.

Build a fresh upload file:

```sh
./scripts/package_web_upload.sh
```

Upload this file to your web host:

```text
climb_on_web_upload.zip
```

The zip is built correctly for static hosts: `index.html` is at the top level.

On iPhone:

1. Open the website in Safari.
2. Tap Share.
3. Tap Add to Home Screen.

On Android:

1. Open the website in Chrome.
2. Tap the menu.
3. Tap Install app or Add to Home screen.

## 2. Free Hosting Recommendation

If Netlify credits are becoming a problem, use Cloudflare Pages direct upload.

In Cloudflare:

1. Go to Workers & Pages.
2. Create a Pages project.
3. Choose Direct Upload.
4. Upload `climb_on_web_upload.zip`.

After Cloudflare gives you a URL, use that new URL everywhere below.

## 3. Google And Supabase Redirects

When your website URL changes, update these places.

In Supabase:

```text
Site URL:
https://YOUR-SITE.pages.dev

Redirect URLs:
https://YOUR-SITE.pages.dev
https://YOUR-SITE.pages.dev/profile/setup
```

In Google Cloud OAuth:

```text
Authorized JavaScript origin:
https://YOUR-SITE.pages.dev

Authorized redirect URI:
https://tlanuiuqvovksrhpelzw.supabase.co/auth/v1/callback
```

In this project, update `.env.local.json`:

```json
{
  "SUPABASE_AUTH_REDIRECT_URL": "https://YOUR-SITE.pages.dev"
}
```

Then rebuild with:

```sh
./scripts/package_web_upload.sh
```

## 4. Downloadable iPhone And Android Apps

The project is already set up with real-style app IDs:

```text
iOS bundle id: ca.climbon.app
Android app id: ca.climbon.app
```

Android local install:

```sh
./scripts/build_android_apk_supabase.sh
```

The APK appears here:

```text
build/app/outputs/flutter-apk/app-release.apk
```

iPhone local build:

```sh
./scripts/build_ios_supabase.sh
open ios/Runner.xcworkspace
```

For an iPhone app that other people can download, you need Apple Developer Program and TestFlight/App Store Connect. For Android public downloads, you need a Google Play Console account. The website/PWA path avoids both of those for now.

Current machine setup:

```text
Website/PWA build: ready
Android APK build: needs Android Studio / Android SDK
iPhone build: needs full Xcode setup and CocoaPods
Store publishing: needs your Apple and Google developer accounts
```

After Android Studio is installed, run:

```sh
flutter doctor
./scripts/build_android_apk_supabase.sh
```

After full Xcode and CocoaPods are installed, run:

```sh
flutter doctor
./scripts/build_ios_supabase.sh
open ios/Runner.xcworkspace
```

## What To Use Right Now

Use Cloudflare Pages plus Add to Home Screen first. It gives you a real website and a phone-home-screen app while you keep building. Move to App Store and Google Play once the core app, logbook, admin tools, and public submissions feel ready.

## Cloudflare Git Build Settings

If Cloudflare is connected to GitHub instead of direct upload, use these settings:

```text
Build command:
./scripts/cloudflare_build.sh

Build output directory:
build/web
```

Leave the deploy command blank.

Cloudflare environment variables:

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
SUPABASE_AUTH_REDIRECT_URL
```
