# Phase 4 Mobile Shipping

Phase 4 focused on making the app easier to try on real phones.

What was added:

- Mobile bottom navigation for compact screens.
- Web app install metadata for a cleaner home-screen install.
- Android app label, location permissions, and internet permission.
- iOS app name cleanup and location permission explanation.
- README instructions for web install, Android APK install, and iPhone/TestFlight paths.

## Recommended Download Path

Use the web app first:

```sh
flutter build web --release
```

Upload `build/web` to an HTTPS host. Then install it from Safari on iPhone or Chrome on Android.

This gives you the fastest phone test without App Store or Google Play setup.

## Native App Path

Android local APK:

```sh
flutter build apk --release
```

iPhone local build:

```sh
flutter build ios --release
open ios/Runner.xcworkspace
```

## Still Needs Your Accounts

Codex cannot finish these without your developer accounts and signing credentials:

- Keep the permanent Android package id `ca.climbon.app`, or change it before the first public store release.
- Create a private Android release signing key before Play Store release.
- Set an Apple developer team in Xcode.
- Create App Store Connect and Google Play listings if you want public store distribution.
- Host the web build on an HTTPS domain if you want home-screen install without app stores.
