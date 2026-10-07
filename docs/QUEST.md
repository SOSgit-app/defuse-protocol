# How to test on Quest 2 / 3 / 3S

DEFUSE PROTOCOL’s Defuser view is **WebXR** in **Meta Quest Browser** over **HTTPS**.

- **VR** — `immersive-vr`: full virtual room + table + bomb  
- **AR** — `immersive-ar` passthrough: your real room, virtual table + bomb (Quest 3 / 3S / Pro; color passthrough)

There is no APK required for the browser path.

## Quick path (recommended): GitHub Pages

1. Open the Pages URL (after deploy):
   ```
   https://sosgit-app.github.io/defuse-protocol/
   ```
   Personal copy: `https://SmallerBytes.github.io/defuse-protocol/`
2. On the Quest, open **Meta Quest Browser** and paste that URL.
3. Choose **DIFFICULTY** (and optional **SEED** / **VIDEO QUALITY**) on the home screen **before** starting.
4. Tap **START IN VR (QUEST)** or **START IN AR (PASSTHROUGH)** and allow the headset session.
5. You’re standing at a table with the bomb. Use the controllers (map below).

`file://` and plain `http://` **will not** start WebXR. Always use `https://`.

### AR notes

- Requires a headset/browser that supports **`immersive-ar`** (Quest 3 / 3S / Pro).
- The dark virtual room, floor, and crates are hidden; passthrough shows through.
- **Plane snap:** aim the reticle at a real table (or floor), then **trigger** to place the bomb. Quest may prompt **room / desk setup** if no planes are found.
- After placing, play as usual. **Y → MOVE BOMB** to snap again.
- Best results: set up a desk surface in Quest **Settings → Boundary → Mixed Reality** (or Space Setup).

## Controller map (Quest Touch)

| Input | Action |
| ----- | ------ |
| **Trigger** (either hand) | Interact / use — cut wire, press keycap, TX, answer, etc. |
| **Left stick** | Head-relative walk (move around the table) |
| **Right stick** left/right | Snap turn **30°** (comfort default) |
| Laser pointer | Aim at module parts (highlight = can select) |

Gameplay cues in VR (HTML HUD is hidden in-headset):

- Timer + strike LEDs live **on the bomb**
- Serial number is engraved on the **front** of the case — walk/snap around to read it
- **Experts outside the headset** use the fixed Field Manual:
  `https://sosgit-app.github.io/defuse-protocol/manual.html`
  (Print → Save as PDF). The in-app manual panel is removed — teammates stay on a phone or laptop.

## Desktop / flat screen

On the same home screen, pick difficulty then **START ON SCREEN**. You can tap **ENTER VR** later if WebXR is available.

## Local HTTPS for Quest (dev)

```bash
npm start
# in another terminal:
cloudflared tunnel --url http://localhost:3210
```

Open the printed `https://…` URL on the Quest.

## Remaining VR / AR limitations

- **HTML HUD** is hidden while presenting; rely on the device timer / LEDs / audio
- **Experts** should use the printed/PDF Field Manual on a phone or laptop — not the headset
- **Perf:** headset sessions force LOW quality (no SSAO/DOF, no point-light shadows). Quest 2 may still dip in dense modules
- **Comfort:** snap turn only (no smooth turn). No teleport yet
- **AR:** plane snap uses hit-test + detected horizontal planes; quality depends on Quest space setup
- Three.js owns stereo / `XRWebGLLayer`; we do **not** stack CRT/barrel post-FX in-headset (Quest already lens-distorts)

## Rebuild solo bundle after server module changes

```bash
npm run build:solo
```
