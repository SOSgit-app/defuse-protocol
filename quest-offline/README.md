# Defuse Protocol — Offline Meta Quest APK

Fully offline WebXR package matching the working classroom pattern:

**APK contains the game → localhost server → Quest Browser → tap START IN VR**

Not Bubblewrap. Not a WebView. No live website required.

## One-time: Horizon App ID

In `android/local.properties` set:

```properties
oculus.app.id=YOUR_NUMERIC_HORIZON_APP_ID
```

Copy it from the Meta Developer Dashboard URL / app settings for **this** Defuse Protocol app.

## Build

```powershell
cd quest-offline
npm run build
```

That syncs `public/` into `assets/www`, vendors Three.js + controller profiles, builds a release APK, and runs verification.

## Sign (same keystore as Alpha forever)

```powershell
$env:BUBBLEWRAP_KEYSTORE_PASSWORD="your-password"
npm run sign
```

Upload `quest-offline/app-release-signed.apk` to the Meta Horizon Developer Dashboard. Raise `versionCode` in `android/app/build.gradle.kts` on every upload.

Do **not** commit the keystore, passwords, or APKs.

## On headset

1. Install the Alpha build (or sideload).
2. Open **Defuse Protocol** from the Library.
3. Quest Browser opens `http://127.0.0.1:8765/` (page is inside the APK).
4. Tap **START IN VR** / **START IN AR** — that tap is the WebXR user gesture.

## Architecture notes

See the Meta dashboard checklist baked into this project:

- `minSdk` / `targetSdk` / `compileSdk` **34**, **arm64-v8a** only
- MetaVR JSDK + `uses-metavr-sdk` 207
- `libopenxr_loader.so` copied into `jniLibs`
- Foreground service `specialUse`, bind **127.0.0.1** only
- Launch `com.oculus.browser` via `ACTION_VIEW`
