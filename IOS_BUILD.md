# iOS build guide (needs a Mac)

iOS apps can only be built and signed on macOS with Xcode. This project was developed on Windows, so **no iOS build has been run or verified**. Everything below is the checked configuration and the exact steps to finish on a Mac.

## What is already configured (checked in the repo)

| Item | Value | File |
|---|---|---|
| Bundle ID | `in.budgetphonewala.app` (same as Android) | `apps/customer_app/ios/Runner.xcodeproj/project.pbxproj` |
| Display name | BudgetPhonewala | `ios/Runner/Info.plist` |
| Minimum iOS | 15.0 | `project.pbxproj` |
| OAuth / email-link return URL | `in.budgetphonewala.app://login-callback` (URL scheme `in.budgetphonewala.app`) | `Info.plist` → `CFBundleURLTypes` |
| Photo / camera permission text | present (sell/exchange photos) | `Info.plist` |
| App icon | generated from the existing logo | `ios/Runner/Assets.xcassets` |
| Signing | Automatic, **no team set** | owner must choose a team |

## Prerequisites (owner)

1. A Mac with Xcode 16 or newer and CocoaPods (`sudo gem install cocoapods` or `brew install cocoapods`).
2. Flutter 3.47.x on the Mac (same version as Windows: see `docs/FLUTTER_SDK.md`).
3. An **Apple Developer Program** membership (paid) to run on a real device beyond 7 days, use TestFlight or publish.
4. The `env/prod.json` file (copy `env/prod.example.json` and fill in the public Supabase URL and anon key; Razorpay key id is fetched from the server at checkout, nothing secret is needed in the app).

## Build steps

```bash
cd apps/customer_app
flutter pub get
cd ios && pod install --repo-update && cd ..
open ios/Runner.xcworkspace        # in Xcode: Runner target > Signing & Capabilities > choose your Team
flutter build ios --release --dart-define-from-file=env/prod.json     # device build
flutter build ipa --release --dart-define-from-file=env/prod.json     # App Store / TestFlight archive
```

Run on a simulator while developing: `flutter run --dart-define-from-file=env/prod.json -d "iPhone 16"`.

## Google sign-in on iOS

1. In Google Cloud Console create an **iOS** OAuth client with Bundle ID `in.budgetphonewala.app` (Team ID and App Store ID can stay empty until you have them).
2. The app signs in through Supabase's web OAuth flow, so the **Web** client already connected in Supabase is the one that matters. The iOS client is only needed if you later switch to native Google Sign-In.
3. Supabase → Authentication → URL Configuration must contain `in.budgetphonewala.app://**` (already added).

## Push notifications (not wired yet)

Push needs an Apple Developer account and cannot be tested without one:

1. Create an APNs key (Apple Developer → Keys) and upload it in Firebase Console → Project settings → Cloud Messaging.
2. In Xcode add the **Push Notifications** and **Background Modes → Remote notifications** capabilities.
3. Add `GoogleService-Info.plist` to `ios/Runner` (git-ignored; do not commit it).

## App Store checklist (owner inputs)

- Privacy policy URL and support URL (the Privacy screen in the app already exposes data export and account deletion, which App Review requires).
- App Privacy "nutrition label" answers: contact info, purchases, identifiers; data is linked to the user and not used for tracking.
- Screenshots (6.9" and 6.5" iPhones) and a test account for review.
- Razorpay on iOS is allowed because the app sells physical goods.

## Known limits

- The unsigned iOS build compiles on Codemagic (macOS). It has not been run on a simulator or a physical iPhone.
- No signing team, certificates or provisioning profiles exist in the repo by design.

## Codemagic (no Mac needed)

The iOS repository is `budgetphonewala2-beep/Budget_Phone_Wala_IOS` (a copy of `apps/customer_app`, pushed with `git subtree split`). It is registered in Codemagic and `codemagic.yaml` defines three workflows:

| Workflow | Needs | Result |
|---|---|---|
| `ios-compile-check` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` variables only | Proves analyze + tests + iOS compile. Verified passing. Not installable |
| `ios-app-store` | Apple Developer Program, app record in App Store Connect, App Store Connect API key named `BudgetPhonewala` | Signed `.ipa` uploaded to App Store Connect (TestFlight); never submitted for review |
| `android-release` | optional upload keystore | APK + AAB |

To get an `.ipa` for your own iPhone:
1. Join the Apple Developer Program (paid).
2. Apple Developer > Devices: register your iPhone's UDID.
3. App Store Connect > Users and Access > Integrations > create an API key; add it in Codemagic (Teams > Integrations > App Store Connect) with the name `BudgetPhonewala`.
4. Start the `ios-app-store` workflow; when App Store Connect finishes processing, add testers in TestFlight and install with the TestFlight app.
