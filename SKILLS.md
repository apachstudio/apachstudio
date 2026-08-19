---
name: liquid-glass-studio-patterns
description: Battle-tested patterns and gotchas for shipping polished SwiftUI components on iOS 26+ with Liquid Glass as the design system. Use when writing or reviewing any view, animation, gesture, or glass surface in this sandbox.
---

# Liquid Glass Studio — Patterns

A skill for building polished SwiftUI components on **iOS 26+**. Patterns
worth reaching for, gotchas worth catching once, and the exact one-liners
that solve them.

This studio targets iOS 26 only — there is **no fallback ceremony**. Reach
for the new APIs (`.glassEffect`, `withAnimation completion:`,
`phaseAnimator`, `keyframeAnimator`) directly. If a component needs to ship
in a multi-iOS app later, that fallback can be added at the integration
seam.

---

## When to apply this skill

- Adding or editing any `.swift` file under `ComponentsStudio/`
- Wiring a new component, animation, or gesture
- Designing chrome (toolbars, FABs, glass surfaces)
- Reviewing PRs that touch UI code

---

## Rules (always)

1. **Never hard-code visual values in components.** Radii and spacing live
   in `Theme.swift`. Colours come from the system (`Color.primary`,
   `Color.secondary`, `Color(.systemBackground)`, materials). If you need
   a brand colour, surface the conversation before adding one — the
   project's design system is glass + system tints by intent.

2. **8-pt spacing grid.** Stick to `Theme.Spacing` values
   (`4, 8, 12, 16, 20, 24, 32, 48`). Anything else is suspicious.

3. **Liquid Glass first.** Default to `.glassEffect(_:in:)`. Plain
   materials (`.ultraThinMaterial`) are a niche fallback for cases where
   glass is too active.

4. **No `Combine`.** Use Swift concurrency (`async / await` +
   `AsyncSequence`). If you find an `@ObservedObject` pattern, audit it
   before propagating.

5. **No `DispatchQueue.main.asyncAfter` for animation sequencing.**
   Use `withAnimation(_:_:completion:)` — see Bottleneck #6.

6. **Two-pass shadows for "premium" elevation.** A tight contact
   shadow + a wide ambient shadow. Single deep shadows look cheap.

7. **`#Preview { }` in every UI file.** Cheap; pays back the first
   time you need to verify a layout without booting the Simulator.

---

## State architecture

### Decision tree

- **Used inside this view only?** → `@State private var`
- **Need a sibling view to read or write it?** → lift to parent;
  pass `@Binding` down
- **Transient (only during a gesture)?** → `@GestureState`
- **From the environment (sheet dismiss, color scheme)?** →
  `@Environment(\.dismiss)`, `@Environment(\.colorScheme)`
- **Long-lived service / loader?** → `@State` on an `@Observable`
  model at the lowest view that needs it

### Lift-up reflex

If two sibling views need to coordinate (e.g. an external button has
to flip state inside an adjacent panel), **lift the state to their
shared parent**. Passing a `@Binding` is cheaper than callbacks and
keeps the invariant in one place.

```swift
// Parent owns the truth:
@State private var isExpanded = false
@State private var showCode   = false

ChildA(isExpanded: $isExpanded)
ChildB(showCode:   $showCode)

// External trigger writes both:
Button("Open") {
    isExpanded = true
    showCode   = true
}
```

---

## Animation conventions

### Picking a curve

| Feel needed                       | Spec                                                |
|-----------------------------------|-----------------------------------------------------|
| Sleek, smooth, no bounce          | `.spring(response: 0.55, dampingFraction: 0.78)`    |
| Premium UI transitions            | `.spring(response: 0.42, dampingFraction: 0.82)`    |
| Bouncy pop                        | `.spring(response: 0.45, dampingFraction: 0.58)`    |
| Snappy / crisp / instant          | `.spring(response: 0.28, dampingFraction: 0.95)`    |
| Floaty / dreamy / slow            | `.easeInOut(duration: 1.4)`                         |
| Critically-damped (no overshoot)  | `.smooth(duration: 0.5)`                            |

**Heuristic:** lower `response` = faster motion. Lower `dampingFraction`
= more bounce.

### Sequenced animations

```swift
withAnimation(inhaleSpring) {
    pop = 0.88
} completion: {
    withAnimation(exhaleSpring) {
        pop = 1.0
    }
}
```

Replaces all `DispatchQueue.main.asyncAfter(deadline: .now() + n)`
patterns. The completion fires exactly when the first animation
settles. Survives interruptions and reorderings cleanly.

### Per-element stagger (cascades)

Don't wrap the toggle in a single `withAnimation`. Apply the
animation modifier per-element:

```swift
ForEach(0..<6) { i in
    item(i)
        .offset(x: expanded ? dx : 0, y: expanded ? dy : 0)
        .scaleEffect(expanded ? 1.0 : 0.05)
        .opacity(expanded ? 1 : 0)
        .animation(spring.delay(Double(i) * 0.05), value: expanded)
}

// State change is now a bare toggle:
expanded.toggle()
```

Each item carries its own delay. The SAME modifier handles open AND
close → directions are guaranteed mirror-symmetric.

### Idle / continuous motion

```swift
TimelineView(.animation(paused: !shouldRun)) { context in
    let t = context.date.timeIntervalSinceReferenceDate
    let phase = t.truncatingRemainder(dividingBy: 5.0) / 5.0
    let scale = 1.0 + 0.02 * CGFloat(sin(phase * .pi * 2))
    YourView().scaleEffect(scale)
}
```

**Always** gate `paused:` when the animation isn't needed. Without
it, the body re-evaluates on every screen refresh forever — kills
batteries.

### Transitions

```swift
.transition(.opacity)
.transition(.scale.combined(with: .opacity))
.transition(.opacity.combined(with: .move(edge: .bottom)))
.transition(.asymmetric(
    insertion: .move(edge: .leading).combined(with: .opacity),
    removal:   .opacity
))
```

> **Pair every `.move` transition with `.clipShape` on the parent.**
> Otherwise the transitioning view briefly renders outside the
> container's visible bounds during the slide.

---

## Liquid Glass surfaces

Two dialects. Pick by role. See [`GUIDELINES.md`](GUIDELINES.md) for the
full design-system framing.

### Dialect A — input surfaces

For text fields, hero cards, primary content surfaces:

```swift
content.glassEffect(.regular, in: shape)                           // rest
content.glassEffect(.regular.tint(.white.opacity(0.42)), in: shape) // focused
```

### Dialect B — chrome / controls

For nav buttons, toolboxes, floating chrome:

```swift
content.glassEffect(.clear.interactive(), in: shape)
```

`.clear` is more transparent than `.regular`. `.interactive()` adds
touch responsiveness.

### Selected "raised" pill (chip-style)

When you want a chip that reads as elevated against a translucent bg:

```swift
Capsule()
    .fill(.ultraThinMaterial)
    .overlay(Capsule().fill(Color.white.opacity(0.70)))
```

Pure material — no glass effect. The white overlay gives the
"raised" affordance; the material gives the translucency.

---

## Gestures

### Drag (the canvas pattern)

```swift
@State private var savedOffset: CGSize = .zero
@GestureState private var dragTranslation: CGSize = .zero

private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 10)
        .updating($dragTranslation) { value, state, _ in
            state = value.translation
        }
        .onEnded { value in
            savedOffset.width  += value.translation.width
            savedOffset.height += value.translation.height
        }
}

// Apply:
.offset(
    x: savedOffset.width  + dragTranslation.width,
    y: savedOffset.height + dragTranslation.height
)
.gesture(dragGesture)
```

**Always use `minimumDistance: 10`** so short taps inside the
gesture area still register on buttons.

### Tap (single + double on the same element)

```swift
Text("Tap me")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { /* double tap action */ }
    .onTapGesture(count: 1) { /* single tap action */ }
```

`Button { }` does NOT compose cleanly with `count: 2`. Drop the
Button and use two `.onTapGesture` modifiers when you need this
combo. Single-tap fires after a small delay (SwiftUI waits to see
if a second tap is coming).

For accessibility, add `.accessibilityAddTraits(.isButton)`.

---

## `matchedGeometryEffect` (moving pills)

For a segmented selector with a single sliding "active pill":

```swift
@Namespace private var pillSpace

ForEach(options) { option in
    Text(option.label)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if option == selected {
                Capsule()
                    .fill(.thinMaterial)
                    .matchedGeometryEffect(id: "pill", in: pillSpace)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selected = option
            }
        }
}
```

> **Each selector needs its own `@Namespace`.** If you have two
> selectors in the same view, each gets its own namespace. The `id:`
> string only needs to be unique within a namespace.

---

## Layout helpers

### Frames

```swift
.frame(width: 20, height: 20)
.frame(maxWidth: .infinity)
.frame(maxWidth: .infinity, alignment: .leading)
.fixedSize(horizontal: true, vertical: false)  // hug content horizontally
```

### Backgrounds and overlays

```swift
.background(.thinMaterial, in: Capsule())      // shorthand

.background {                                  // explicit shape
    Capsule().fill(.thinMaterial)
}

.background {                                  // layered
    ZStack {
        Capsule().fill(.ultraThinMaterial)
        Capsule().fill(Color.white.opacity(0.40))
    }
}

.overlay(                                      // border
    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
)
```

### Two-pass shadows ("premium")

```swift
.shadow(color: .black.opacity(0.06), radius: 4,  x: 0, y: 2)   // contact
.shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 10)  // ambient
```

### Clipping content vs shadow — order matters

```swift
.background { /* glass surface */ }
.clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
.shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 10)
```

Clip BEFORE shadow → shadow stays outside the clip. Clip AFTER
shadow → shadow gets cut off.

---

## Conditional rendering

```swift
// Single branch
if isLoading {
    ProgressView()
}

// Two branches with transitions
Group {
    if showCode {
        codeBox.transition(.opacity)
    } else {
        slidersPanel.transition(.opacity)
    }
}

// Switch over an enum (needs @ViewBuilder)
@ViewBuilder
var body: some View {
    switch category {
    case .motion:   motionSliders
    case .position: positionSliders
    }
}
```

### `@ViewBuilder` on helper functions

When a helper returns different view types in different branches:

```swift
@ViewBuilder
private func chip(for option: Option) -> some View {
    if option.isSelected {
        FilledChip(option: option)
    } else {
        OutlineChip(option: option)
    }
}
```

Without `@ViewBuilder`, the compiler can't unify the two branches.

---

## Top 10 bottlenecks (and the fixes)

### 1. `ForEach` inside `TimelineView` without a `ZStack`

**Symptom:** Layout breaks; views stack vertically; siblings disappear.

**Why:** `TimelineView`'s content closure returns ONE view. A bare
`ForEach` defaults to a vertical stack.

**Fix:** Wrap the `ForEach` in an explicit layout container:

```swift
TimelineView(.animation) { _ in
    ZStack {                       // MUST have this
        ForEach(0..<6) { i in
            item(i).offset(x: dx, y: dy)
        }
    }
}
```

### 2. Slider tint only takes `Color` (no `ShapeStyle`)

**Symptom:** `.tint(.thinMaterial)` doesn't compile.

**Fix:** Approximate with `Color.black.opacity(0.20)` and put the
material treatment on the SLIDER TRAY behind it.

### 3. `clipShape` after `shadow` cuts the shadow

**Fix:** Apply `.clipShape` BEFORE `.shadow`. See "Clipping" above.

### 4. Drag eats button taps

**Fix:** `DragGesture(minimumDistance: 10)`. For very precise needs,
scope the drag to a dedicated drag handle. See "Drag (the canvas
pattern)" above.

### 5. `.regular` glass on chrome looks too solid

**Fix:** Use `.clear.interactive()` for nav buttons, toolboxes, and
floating chrome. Reserve `.regular` for input surfaces.

### 6. `DispatchQueue.main.asyncAfter` for animation timing

**Symptom:** Jittery sequences, race conditions, hard to interrupt.

**Fix:** `withAnimation(_:_:completion:)`. Always.

### 7. `withAnimation` on a shared state for cascades

**Symptom:** All N items animate together; no stagger.

**Fix:** Per-element `.animation(spring.delay(...), value: trigger)`.
Drop the `withAnimation` wrap.

### 8. `matchedGeometryEffect` IDs colliding across selectors

**Symptom:** The pill animates between unrelated selectors.

**Fix:** One `@Namespace` per selector. IDs are scoped to namespaces.

### 9. Per-element blur in a large grid

**Symptom:** GPU melts. Frame rate plummets.

**Fix:** Use opacity / scale to fake "blur fade" at the edges.
Reserve real `BlurView` for ≤ 3 instances per screen.

### 10. Continuous `TimelineView` without `paused:` gating

**Fix:** `TimelineView(.animation(paused: !shouldRun))`. Without it,
the body re-evaluates every screen refresh forever.

---

## SF Symbols (the ones reached for most)

```
wrench.and.screwdriver.fill   ← dev tools / specs FAB
slider.horizontal.3           ← customize / adjust
doc.on.doc                    ← copy
checkmark                     ← success
xmark                         ← dismiss
chevron.up / down / left / right
                              ← expand/collapse/back/forward
record.circle                 ← recording mode
circle.grid.3x3.fill          ← grid
rectangle.stack.fill          ← deck / stacked
magnifyingglass               ← search
ellipsis                      ← more actions
arrow.up.forward              ← external / outbound
sparkles                      ← AI-driven affordances
star.fill                     ← rating
heart.fill                    ← favorite
```

---

## Platform features used a lot

### Clipboard

```swift
#if canImport(UIKit)
UIPasteboard.general.string = generatedCode
#endif
```

### Haptics

```swift
#if canImport(UIKit)
UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
```

`.soft` = ambient confirmations · `.medium` = selection changes ·
`.light` = ticks.

### Selectable monospaced text (code preview)

```swift
Text(code)
    .font(.system(.body, design: .monospaced))
    .textSelection(.enabled)
```

### Non-jittery numeric display

```swift
Text(String(format: "%.2f", value))
    .font(.system(.body).monospacedDigit())
```

### Accessibility minimums

```swift
.accessibilityLabel("Open generated code")
.accessibilityHint("Double tap to expand")
.accessibilityAddTraits(.isButton)
.accessibilityAddTraits([.isButton, .isSelected])
.accessibilityElement(children: .ignore)        // own the a11y story
                                                // for a composite view
```

---

## Code style

- **Naming**: `PascalCase` for types, `camelCase` for everything else.
- **Properties**: `let` whenever possible; `@State private var` for
  SwiftUI state.
- **Indentation**: 4 spaces.
- **Imports**: `SwiftUI` / `Foundation` first; UIKit last.
- **Comments**: explain the *why*, not the *what*. The name + the
  type should explain *what*; a comment is only there when there's
  a non-obvious constraint or design decision.
- **`// MARK:` headers** in any file > 300 lines, between logical
  sections.
- **Force unwrap (`!`)**: never in production paths. Prefer
  `guard let` with a clear invariant or a `fatalError` that explains
  the assumption.

---

## Workflow

1. **Build first, read docs second.** Run an in-IDE diagnostic
   refresh after every edit before moving on. Catches typos,
   hallucinated APIs, broken types in <2 s.
2. **Full project build** (`BuildProject` / `⌘ B`) after any change
   that touches `Theme.swift` or `ComponentStudioView.swift`.
3. **The Studio IS the workflow.** Every component gets a stage entry
   in `ComponentStudioView`. Iterate on the stage, not in the abstract.
4. **`#Preview { }`** at the bottom of every UI file. Cheap; pays
   back the first time you need to verify a layout without booting.
5. **`DocumentationSearch` for new APIs.** Anything iOS 26-flavoured
   (`glassEffect`, `phaseAnimator`, `keyframeAnimator`,
   FoundationModels) has likely changed since your training data.
   Search Apple's docs before using.

---

## Design tokens — the rule

Centralise reusable geometric values in `Theme.swift`. Components
import them; never inline a radius / px / spacing in component code.
Colours, by contrast, come from the system (`Color.primary`,
`Color.secondary`, materials) — Liquid Glass is the colour story.

When the user asks "make this darker", reach for `.opacity()` first;
add a new token only if the change is reusable in ≥ 2 components.

---

## Anti-patterns

- Adding a new px / radius inline in a component instead of `Theme`
- Adding brand colour tokens (this project is glass + system tints)
- Per-element blur in a grid
- `DispatchQueue.main.asyncAfter` for animation sequencing
- One `withAnimation` for an N-element cascade
- `.regular` glass on chrome (use `.clear.interactive()`)
- `Button { }` + `.onTapGesture(count: 2)` (they fight)
- Force-unwrapping (`!`) — use `guard let` with a clear invariant
- `Combine` (use Swift concurrency)
- Missing `paused:` on a continuous `TimelineView`
- `.clipShape` after `.shadow`
- Reusing one `@Namespace` across multiple selectors

---

## When in doubt

If a SwiftUI behavior is unexpected:

1. Check that the closure is returning ONE view (wrap in a container if not).
2. Check `@Namespace` scoping for matched geometry effects.
3. Check that `paused:` is gated correctly on `TimelineView`.
4. Check the order of `.background` / `.clipShape` / `.shadow`.
5. Check for `Combine` patterns that should be async.

Have fun.
