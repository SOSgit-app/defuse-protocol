# Defusal App Lab (`defusalapplab`)

Meta Quest **Alpha / Store** packaging for Defuse Protocol using Meta’s official **Bubblewrap** WebXR PWA path.

Students install from an Alpha invite link — **no Developer Mode**, no SideQuest, no ADB on each headset.  
The headset needs **Wi‑Fi** to load the live game from GitHub Pages (this is a web wrapper, not a native offline APK).

**App mode:** `horizonOSAppMode` is **`immersive`**. Meta’s 2D panel mode cannot start WebXR
(`immersive-vr is not supported on this headset`). The installed Alpha app auto-enters VR on
launch; Quest Browser still uses the on-screen START IN VR / AR buttons.

This folder is separate from [`quest-offline/`](../quest-offline/) (sideload / Unknown Sources).

## What Meta needs

| Piece | Where |
| ----- | ----- |
| Hosted HTTPS game + PWA manifest | [`public/manifest.webmanifest`](../public/manifest.webmanifest) on Pages |
| Icons | [`public/icons/`](../public/icons/) |
| Digital Asset Links | [`public/.well-known/assetlinks.json`](../public/.well-known/assetlinks.json) |
| Immersive Bubblewrap APK | Built here → `app-release-signed.apk` |
| App Lab listing | [Meta Developer Dashboard](https://developers.meta.com/manage/) |

## One-time setup

### 1. Deploy the web PWA bits

Commit/push the `public/` changes (manifest, icons, `.well-known`, App Lab auto-VR hook), then confirm:

- https://sosgit-app.github.io/defuse-protocol/manifest.webmanifest  
- https://sosgit-app.github.io/defuse-protocol/icons/icon-512.png  

(If you wrap **SmallerBytes** Pages instead, edit `host` / URLs in `twa-manifest.template.json` before init.)

### 2. Meta developer org + App Lab app

1. Create / join a [Meta developer organization](https://developers.meta.com/).
2. Create an app → enable distribution for **App Lab** (or Store later).
3. Note the Horizon Application ID if you ever add IAP (not required for this free classroom build).

### 3. Init Bubblewrap in this folder

```powershell
cd defusalapplab
npm run init
```

This will:

- Copy `twa-manifest.template.json` → `twa-manifest.json`
- Install `@meta-quest/bubblewrap-cli`
- Prompt you to create `android.keystore` (**back this file up** — same key forever)

Confirm `twa-manifest.json` has:

```json
"horizonOSAppMode": "immersive",
"isMetaQuest": true
```

### 4. Fingerprint → assetlinks → redeploy

```powershell
npm run fingerprint
```

Paste the `SHA256:` value into `public/.well-known/assetlinks.json` under `sha256_cert_fingerprints`, then push/deploy Pages again. Verify:

```text
https://sosgit-app.github.io/defuse-protocol/.well-known/assetlinks.json
```

Also (from this folder, after Bubblewrap is installed):

```powershell
bubblewrap fingerprint add <sha256-with-colons>
```

### 5. Build the signed APK

```powershell
npm run update
```

**On Windows**, do **not** use `npm run build` (Bubblewrap hits `spawn EINVAL` on Node 20+/24). Use:

```powershell
npm run build:windows
```

Enter your keystore password when asked. Output:

`defusalapplab/app-release-signed.apk`

Needs ~5–8 GB free on `C:` and Android Studio’s SDK at `%LOCALAPPDATA%\Android\Sdk`.

### 6. Upload to App Lab

In the Developer Dashboard, upload the signed APK / package for your App Lab channel and fill the listing (name, screenshots, age rating, privacy policy URL if required).

Share the **App Lab install link** with class headsets. They install like a normal app — **Unknown Sources / Developer Mode not required**.

## Test before App Lab

On one Quest with Developer Mode (optional):

```powershell
adb install -r app-release-signed.apk
```

Or use `npm run install-device` if Bubblewrap’s install helper works with your ADB path.

Launch the app icon — it should open immersive WebXR (PWA detects Digital Goods and auto-starts VR).

## Classroom note

- **Teammates** still use the Field Manual on a phone/laptop (`manual.html` or the same Pages site).
- Headsets need network access to your Pages origin.
- For true offline / no Wi‑Fi, use [`quest-offline/`](../quest-offline/) instead (requires Developer Mode).

## Official Meta docs

- [Get started with PWA packaging](https://developers.meta.com/horizon/documentation/web/pwa-overview-gs/)
- [WebXR PWA support](https://developers.meta.com/horizon/documentation/web/pwa-webxr/)
- [Package a PWA (Bubblewrap)](https://developers.meta.com/horizon/documentation/web/pwa-packaging/)
