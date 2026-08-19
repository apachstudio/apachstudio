# Components Studio

A standalone Xcode project — a clean, white-canvas sandbox for building and
recording **iOS 26+ Liquid Glass** components. No app shell, no models, no
backend: each component renders on the same neutral stage so you can iterate
on visuals and motion in isolation.

---

## Run it

The `.xcodeproj` is not committed — generate it from `project.yml`:

```sh
brew install xcodegen      # one-time
xcodegen generate          # creates ComponentsStudio.xcodeproj
open ComponentsStudio.xcodeproj
```

Then run on an **iOS 26 (or later) simulator**.

Re-run `xcodegen generate` whenever you add or rename source files.

---

## Layout

```
ComponentsStudio/
├── ComponentsStudioApp.swift   @main entry; pins light scheme
├── Theme.swift                 Geometric tokens (radii, spacing) — no colors
└── ComponentStudioView.swift   Navigation shell + Stage + recording mode
```

Add new components as their own `.swift` file under `ComponentsStudio/`, then
register them in `StudioItem` (inside `ComponentStudioView.swift`).

Components with tunable specs should use the shared `UnifiedStudioStage`
instead of custom toolbar chrome. The unified stage owns the bottom FAB dock
and expanded controls panel; expanded content is capped at 150pt with native
scrolling so stage changes stay visible while tuning.

---

## Design system

**Liquid Glass only.** The two dialects (input surfaces vs chrome) and the
rules of the road are spelled out in [`GUIDELINES.md`](GUIDELINES.md). The
recurring SwiftUI patterns and gotchas live in [`SKILLS.md`](SKILLS.md).

System materials and `Color.primary` / `Color.secondary` do all the colour
work — `Theme` only owns radii and spacing.

---

## Recording mode

Triple-tap the stage to hide chrome (nav bar, back chevron, title) for a
clean screen recording. Triple-tap again to bring it back.
