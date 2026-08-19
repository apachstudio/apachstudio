# Components Studio → Figma importer (HIG-aware)

A Figma plugin that **audits** the Components Studio app, detects the native iOS
(HIG / UIKit / SwiftUI) components, and recreates every screen as an **editable**
iPhone frame (402 × 874) — with the native parts rebuilt to Apple's published specs.

- **Native components** (nav bar, inset-grouped list, disclosure rows, back button,
  status bar, sliders, switches, Liquid Glass) are rebuilt to **HIG specs**:
  system colors, exact metrics, **SF Pro** + SF-Symbol-style glyphs.
- **Shader / preview art** is embedded as an image fill — Metal renders can't be
  vectorised, so they live inside an editable rounded card.
- An **Audit / Specs frame** is generated documenting each detected native
  component, its Apple class name, and key spec values.

## Fonts — SF Pro vs Inter

The plugin tries to use **SF Pro Text / SF Pro Display** at runtime.

- If you have Apple's SF Pro installed (free: https://developer.apple.com/fonts/),
  the screens render in the real system typeface.
- If not, it falls back to **Inter** automatically (a near-identical metric match).

The notification + the Audit frame tell you which one was used.

> Note: this is a **spec-accurate reconstruction**, not Apple's proprietary Figma
> component instances. For literal Apple-kit instances, import Apple's "Apple
> Design Resources – iOS" library and swap the rebuilt layers for kit components.

## What gets created (16 frames)

| Frame | Fidelity |
|---|---|
| Audit · iOS HIG components | Spec sheet: native components → Apple class + metrics |
| Home | Fully native / editable — UINavigationBar + inset-grouped UITableView, disclosure rows |
| 9 shader pages | HIG chrome (status bar, glass back button, FABs) + shader as image in the card |
| Satelite Cards, Glass Pill, Summary Blur Loading, Vertical card deck, AI Search | Full screenshot as the frame image (flat) |

## How to run it (needs Figma Desktop)

Importing a development plugin from a manifest is only available in the **Figma
desktop app** (not the browser).

1. Open the Figma desktop app and open the file you want the screens added to.
2. **Plugins → Development → Import plugin from manifest…** → pick `plugin/manifest.json`.
3. Run **Plugins → Development → Components Studio Import**.

It builds the audit frame + 15 screens, selects them, and zooms to fit.

## Editing / regenerating

- `_logic.js` — the human-readable builder (audit data, HIG specs, layout, colors).
- `images.js` — auto-generated base64 of the cropped shader cards + flat screens.
- `code.js` — `images.js` + `_logic.js` concatenated (loaded by the manifest).

After editing `_logic.js`, rebuild with:

```sh
cat images.js _logic.js > code.js
```
