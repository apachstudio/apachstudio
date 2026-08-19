# Design guidelines — Liquid Glass studio

This project has one design system: **Liquid Glass on iOS 26+**, with the
system's own materials and tints filling in around it. Every component
built here should feel native to that vocabulary the moment you drop it
into a real app.

> The implementation patterns live in [`SKILLS.md`](SKILLS.md). This
> document is the *why* — the design intent and the boundaries.

---

## North star

A component looks "right" when it could plausibly be a stock SwiftUI
control on iOS 26: glass surfaces that refract the layer below,
animations that feel weighted, typography from the system ramp, colour
that flexes with the user's environment.

If a component needs ten lines of custom shadow / gradient / colour to
look good in this studio, it will not look good in someone else's app.
Lean on the system. The studio is the place to *find* the smallest set
of moves that produces the polish, not pile on effects until it looks
shippable.

---

## Surfaces — two dialects of glass

`.glassEffect` has two distinct flavours. Components should commit to
one — mixing them in the same surface looks muddled.

### Dialect A — input / content surfaces

Use when the surface **carries content** the user is reading, editing,
or focused on: search pills, hero cards, sheets, primary plates.

```swift
content.glassEffect(.regular, in: shape)                            // rest
content.glassEffect(.regular.tint(.white.opacity(0.42)), in: shape) // focused
```

- `.regular` is the heavier glass — more refraction, more presence.
- The tinted variant gives a clean "active" affordance without resorting
  to a coloured stroke or shadow.

### Dialect B — chrome / control surfaces

Use for **floating chrome and controls**: nav buttons, toolboxes,
floating FABs, mode toggles, anything the user *acts through* rather
than *acts on*.

```swift
content.glassEffect(.clear.interactive(), in: shape)
```

- `.clear` is markedly more transparent than `.regular`. Chrome should
  read as on top of, not embedded in, the canvas.
- `.interactive()` adds touch responsiveness — the glass acknowledges
  the press without needing a separate `scaleEffect`.

### When to use plain materials instead

`.ultraThinMaterial` (and friends) are still the right call in two
cases:

1. **A "raised" chip / pill** that needs to read as elevated above
   a translucent backdrop:
   ```swift
   Capsule()
       .fill(.ultraThinMaterial)
       .overlay(Capsule().fill(Color.white.opacity(0.70)))
   ```
2. **A surface where glass is too active** — typically dense panels
   with lots of small text. Glass refraction can fight legibility at
   small type sizes.

Otherwise: glass.

---

## Colour

**The studio does not own brand colour tokens.** Components should reach
for:

- `Color.primary` / `Color.secondary` / `Color(.label)` for text
- `Color(.systemBackground)` / `Color(.secondarySystemBackground)` for canvases
- Materials (`.thinMaterial`, `.ultraThinMaterial`, `.regularMaterial`)
- `.tint(_:)` accents — let the host app drive the brand colour
- `.opacity(_:)` for tone hierarchy ("a quieter version of this")

When you genuinely need a stable accent, prefer the system's own:
`.tint(.accentColor)` or a system-named tint like `.blue` / `.indigo`.

This isn't dogma — it's because components written against system colour
slot into any host app without dragging a palette with them. The moment
a component hard-codes `Color(hex: 0xCDE34D)`, it stops being portable.

---

## Geometry — the tokens we do own

`Theme.swift` holds **radii and spacing only**. These are the
geometric "fingerprint" of a Liquid Glass app — get them consistent
and components compose; let them drift and the catalog looks like
five different studios.

### Radii

| Token              | Use                                                     |
|--------------------|---------------------------------------------------------|
| `Theme.Radius.chip`   (14) | Inline chips, small badges                       |
| `Theme.Radius.card`   (28) | Standard content cards, list rows                |
| `Theme.Radius.sheet`  (44) | Hero plates, full-bleed sheets                   |
| `Theme.Radius.pill`  (999) | Capsule controls (prefer `Capsule()` when possible) |

### Spacing — 8-pt grid

`4, 8, 12, 16, 20, 24, 32, 48`. Period. If a layout *demands* something
else, surface it before adding the token — usually it means the rhythm
is off somewhere else.

---

## Motion

Liquid Glass surfaces look most convincing with **slightly under-damped
springs** — the glass should feel like it has mass.

Default vocabulary:

| Use                              | Spring                                                 |
|----------------------------------|--------------------------------------------------------|
| Premium UI transitions           | `.spring(response: 0.42, dampingFraction: 0.82)`       |
| Sleek, smooth, no bounce         | `.spring(response: 0.55, dampingFraction: 0.78)`       |
| Bouncy pop / haptic confirm      | `.spring(response: 0.45, dampingFraction: 0.58)`       |
| Snappy / instant                 | `.spring(response: 0.28, dampingFraction: 0.95)`       |

Specifics live in [`SKILLS.md`](SKILLS.md#animation-conventions). The
short version: **don't reach for `easeInOut` by reflex on glass**.
Springs read as physical; easing reads as scripted.

---

## Typography

The system ramp does the work:

```swift
.font(.system(.body, design: .rounded).weight(.medium))   // friendly UI body
.font(.system(.title3).weight(.semibold))                 // section headers
.font(.system(.caption).monospacedDigit())                // numeric readouts
```

- **`.rounded`** is the studio's default voice for control labels — it
  pairs naturally with capsule glass surfaces.
- Honour Dynamic Type. Use `.font(.system(_:))` styles, not custom point
  sizes. `relativeTo:` for any custom font you bundle.

---

## Anti-patterns (specific to this DS)

- **Brand-coloured glass.** If `.tint(_:)` isn't enough, the component
  is asking for a host-app concern. Don't bake colour into the studio.
- **Layering glass on glass.** Two `.glassEffect` surfaces stacked
  cancel the refraction. If you need an "elevated" layer above glass,
  use a plain material with a white overlay (see "raised pill" above).
- **Heavy custom shadows on glass surfaces.** Liquid Glass already
  reads as elevated. Adding a deep shadow makes it look pasted-on.
  Use shadows for *non-glass* elevation cues only.
- **Custom gradient backdrops** that fight the glass refraction. The
  surface beneath should be coherent — a system background, a system
  material, or a single image — not a hand-rolled gradient.
- **Single deep shadow** for "elevation". Use the two-pass shadow
  pattern (contact + ambient) — never on glass; only on flat surfaces.

---

## Component checklist

Before a component is considered "done" in this studio:

- [ ] Renders on the studio stage at the default Dynamic Type size
- [ ] Renders correctly at the largest accessibility text size
- [ ] Honours `Reduce Motion` (drop the spring; keep the state change)
- [ ] Honours `Reduce Transparency` (the glass surface degrades
      gracefully — usually to a solid material)
- [ ] Has VoiceOver labels / hints / traits
- [ ] Has a `#Preview { }` at the bottom of the file
- [ ] Uses `Theme.Radius` / `Theme.Spacing` — no inline geometry
- [ ] Uses system colours / materials — no hex literals
