# Phase 2: Progress Indicators - Research

**Researched:** 2026-01-30
**Domain:** SwiftUI Progress UI, Haptic Feedback
**Confidence:** HIGH

## Summary

This phase focuses on enhancing the existing progress display with a determinate ProgressView and adding haptic feedback on processing completion. The research reveals that most of the infrastructure is already in place:

- **ProcessingViewModel** already tracks `processingProgress: (current: Int, total: Int)`
- **ProcessingView** already displays this as "X of Y screenshots" text and has a custom `ProgressRing` component
- **sensoryFeedback** modifier is already used in the codebase (OnboardingView, ProcessingView button)

The primary work is: (1) adding SwiftUI's native `ProgressView(value:total:)` for a determinate linear bar, (2) adding `.sensoryFeedback(.success)` triggered when `isProcessing` transitions from `true` to `false` with results.

**Primary recommendation:** Add a native SwiftUI `ProgressView(value:total:)` below the existing ProgressRing for a linear bar, and add completion haptic using `.sensoryFeedback(.success, trigger:)` with a condition that fires only on successful completion.

## Standard Stack

This phase uses only SwiftUI built-in components. No additional libraries needed.

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI ProgressView | iOS 14+ | Determinate linear progress bar | Native, performant, automatically styled |
| sensoryFeedback modifier | iOS 17+ | Haptic feedback on completion | Native SwiftUI API, replaces UIKit haptics |
| @Observable | iOS 17+ | ViewModel state (already implemented) | Modern Swift observation, automatic UI updates |

### Already Implemented (No Change Needed)
| Component | Location | What It Does |
|-----------|----------|--------------|
| `processingProgress` property | ProcessingViewModel | Tracks `(current: Int, total: Int)` |
| `ProgressRing` | DesignSystem.swift | Custom circular progress indicator |
| Progress text | ProcessingView | Shows "X of Y screenshots" |
| `.sensoryFeedback(.impact)` | ProcessingView line 226 | Triggers when `isProcessing` changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftUI ProgressView | Custom Capsule-based bar | Current custom bar works but ProgressView adds accessibility |
| sensoryFeedback | UIImpactFeedbackGenerator | sensoryFeedback is declarative, trigger-based, cleaner |

**Installation:** None needed - all components are built into SwiftUI.

## Architecture Patterns

### Current Progress Flow
```
ProcessingViewModel.processNow()
  └─> for loop: processingProgress = (index + 1, total)
        └─> ProcessingView observes via @Observable
              └─> ProgressRing updates
              └─> Text updates ("X of Y screenshots")
```

### Pattern 1: Determinate ProgressView with Value Binding
**What:** SwiftUI's `ProgressView(value:total:)` displays a linear progress bar that fills based on current/total values.
**When to use:** When you know how many items will be processed (determinate progress).
**Example:**
```swift
// Source: https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/
ProgressView(
    value: Double(viewModel.processingProgress.current),
    total: Double(max(viewModel.processingProgress.total, 1))
)
.progressViewStyle(.linear)
.tint(Color(hex: "6366F1"))
```

### Pattern 2: Conditional Haptic Feedback
**What:** The `sensoryFeedback` modifier can include a condition closure to control when feedback fires.
**When to use:** When you need feedback only on specific state transitions (not every change).
**Example:**
```swift
// Source: https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/
// Fires success haptic only when processing completes with results
.sensoryFeedback(.success, trigger: viewModel.isProcessing) { oldValue, newValue in
    // Fire when transitioning from processing (true) to done (false)
    // and we have results
    oldValue == true && newValue == false && !viewModel.results.isEmpty
}
```

### Pattern 3: Animation Scoping for Progress Updates
**What:** Limit animation scope to prevent layout thrashing during frequent updates.
**When to use:** When progress updates many times per second.
**Example:**
```swift
// Source: existing ProcessingView.swift line 282
// Animation is scoped to just the progress value, not entire view
.animation(.spring(response: 0.4), value: viewModel.processingProgress.current)
```

### Anti-Patterns to Avoid
- **Animating entire view on progress change:** Don't use `.animation()` on parent containers; scope to specific values
- **Multiple overlapping animations:** The existing code correctly uses `animation(_:value:)` not broad `.animation()`
- **Raw UIKit haptics in SwiftUI:** Use `sensoryFeedback` modifier, not `UIImpactFeedbackGenerator` directly

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Linear progress bar | Custom GeometryReader + Capsule | `ProgressView(value:total:)` | Accessibility built-in, handles edge cases |
| Haptic feedback | UIImpactFeedbackGenerator wrapper | `.sensoryFeedback()` modifier | Declarative, trigger-based, less code |
| Progress throttling | Manual timer/debounce | Rely on @Observable coalescing | SwiftUI already coalesces rapid updates |

**Key insight:** The existing custom progress bar (Capsule-based) works fine visually, but adding a native `ProgressView` provides accessibility features (VoiceOver announces progress) that custom implementations miss.

## Common Pitfalls

### Pitfall 1: UI Thrashing from Frequent Progress Updates
**What goes wrong:** Progress updates every iteration (could be 100+ times) causing excessive view recomputation.
**Why it happens:** Each `processingProgress` mutation triggers an observation update.
**How to avoid:**
- SwiftUI's @Observable already coalesces rapid updates within same run loop tick
- The existing animation scoping (`animation(_:value:)`) prevents cascading redraws
- If needed, can throttle updates to every N items (but likely unnecessary)
**Warning signs:** Profiler shows excessive body evaluations, visible stutter during processing.

### Pitfall 2: Haptic Firing Multiple Times
**What goes wrong:** Success haptic plays repeatedly instead of once on completion.
**Why it happens:** Trigger value changes multiple times, or condition doesn't properly gate.
**How to avoid:** Use the condition closure to check both old and new values:
```swift
.sensoryFeedback(.success, trigger: viewModel.isProcessing) { old, new in
    old == true && new == false // Only on true->false transition
}
```
**Warning signs:** Phone vibrates multiple times when processing finishes.

### Pitfall 3: Haptic on Cancellation
**What goes wrong:** Success haptic plays even when user cancels processing.
**Why it happens:** `isProcessing` transitions to `false` on cancel too.
**How to avoid:** Include results check in condition:
```swift
{ old, new in old == true && new == false && !viewModel.results.isEmpty }
```
**Warning signs:** Haptic plays when hitting Cancel button.

### Pitfall 4: Progress Animation Jank
**What goes wrong:** Progress bar jumps or stutters instead of smooth fill.
**Why it happens:** Missing or conflicting animation modifiers.
**How to avoid:** Use spring animation with reasonable response time:
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
```
**Warning signs:** Progress bar visibly "teleports" between values.

## Code Examples

### Adding Determinate ProgressView to Existing processingSection
```swift
// Source: https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/
// Add below existing ProgressRing in processingSection

let progress = Double(viewModel.processingProgress.current) /
               Double(max(viewModel.processingProgress.total, 1))

ProgressView(value: progress)
    .progressViewStyle(.linear)
    .tint(Color(hex: "6366F1"))
    .animation(.spring(response: 0.3), value: progress)
```

### Completion Haptic with Condition
```swift
// Source: https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/
// Add to NavigationStack in ProcessingView body

.sensoryFeedback(.success, trigger: viewModel.isProcessing) { oldValue, newValue in
    // Only fire on processing completion (true -> false) with results
    oldValue == true && newValue == false && !viewModel.results.isEmpty
}
```

### Available Feedback Types for Reference
```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback
.sensoryFeedback(.success, trigger: ...)  // Task completed successfully
.sensoryFeedback(.error, trigger: ...)    // Something went wrong
.sensoryFeedback(.warning, trigger: ...)  // Attention needed
.sensoryFeedback(.selection, trigger: ...) // UI selection changed
.sensoryFeedback(.impact(flexibility: .soft), trigger: ...) // Physical interaction
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIProgressView (UIKit) | SwiftUI ProgressView | iOS 14 (2020) | Declarative, automatic updates |
| UIImpactFeedbackGenerator | sensoryFeedback modifier | iOS 17 (2023) | Trigger-based, conditional support |
| @ObservableObject + @Published | @Observable macro | iOS 17 (2023) | Finer-grained observation, less boilerplate |

**Deprecated/outdated:**
- Direct use of `UINotificationFeedbackGenerator` in SwiftUI: Replace with `sensoryFeedback` modifier
- `.animation()` without value parameter: Use `.animation(_:value:)` to scope animations

## Open Questions

1. **Should we replace the custom Capsule progress bar entirely?**
   - What we know: Both custom bar and native ProgressView work. Native provides accessibility.
   - What's unclear: Whether visual design requires the custom gradient styling.
   - Recommendation: Keep both initially - ProgressRing for visual flair, ProgressView for accessibility. Can simplify later.

2. **Should milestone haptics be added (e.g., every 10 items)?**
   - What we know: Mentioned in FEATURES.md as "Hierarchical haptics during progress"
   - What's unclear: Whether this is scope for Phase 2 or a separate enhancement.
   - Recommendation: Out of scope for Phase 2. Focus on completion haptic first.

## Sources

### Primary (HIGH confidence)
- Existing codebase: ProcessingViewModel.swift, ProcessingView.swift, DesignSystem.swift - verified current implementation
- [Hacking with Swift - sensoryFeedback](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback) - API usage patterns
- [Swift with Majid - Sensory Feedback](https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/) - Conditional triggers
- [Swift with Majid - Mastering ProgressView](https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/) - ProgressView patterns

### Secondary (MEDIUM confidence)
- [SwiftUI Performance Tuning Guide (Jan 2026)](https://www.sachith.co.uk/ios-swiftui-data-flows-performance-tuning-guide-practical-guide-jan-7-2026/) - Throttling patterns
- [Sarunw - SwiftUI ProgressView](https://sarunw.com/posts/swiftui-progressview/) - Basic usage

### Tertiary (LOW confidence)
- WebSearch results on throttling best practices - multiple sources agree on animation scoping

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all SwiftUI built-in, verified in existing codebase
- Architecture: HIGH - patterns directly from official-adjacent sources (Hacking with Swift, Swift with Majid)
- Pitfalls: HIGH - derived from understanding existing code and verified patterns

**Research date:** 2026-01-30
**Valid until:** 60 days (stable SwiftUI APIs, unlikely to change)

---

## Implementation Checklist for Planner

Based on this research, Phase 2 implementation should:

1. [ ] Add `ProgressView(value:total:)` to `processingSection` in ProcessingView
2. [ ] Style with `.tint()` to match app theme
3. [ ] Add completion haptic via `.sensoryFeedback(.success, trigger:)` with condition
4. [ ] Verify haptic only fires on successful completion (not cancellation)
5. [ ] Test progress updates don't cause UI stutter
6. [ ] Verify VoiceOver announces progress (accessibility check)
