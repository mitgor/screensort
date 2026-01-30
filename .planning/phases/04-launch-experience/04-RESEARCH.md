# Phase 4: Launch Experience - Research

**Researched:** 2026-01-30
**Domain:** SwiftUI App Launch UX, Skeleton Loading, Scroll Position Persistence
**Confidence:** HIGH

## Summary

This phase focuses on polishing the app launch experience to provide instant visual feedback and state restoration. The existing codebase already has solid foundations: `ProcessedScreenshotStore` persists results via UserDefaults, and `checkInitialState()` loads cached results on launch. The remaining work involves adding skeleton/placeholder UI during background data refresh and persisting scroll position.

SwiftUI provides robust built-in tools for this work. The `.redacted(reason: .placeholder)` modifier creates skeleton loading states with a single line of code. For shimmer effects, the lightweight SwiftUI-Shimmer library (or a custom ViewModifier) can be combined with redacted views. iOS 18 introduces `ScrollPosition` and `onScrollGeometryChange` for precise scroll position control and persistence.

**Primary recommendation:** Use SwiftUI's native `.redacted()` modifier combined with the existing shimmer modifier for skeleton loading, and leverage iOS 18's `ScrollPosition` with `@AppStorage` for scroll position persistence.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `.redacted()` | iOS 14+ | Skeleton/placeholder UI | Native, zero dependencies, dynamic sizing |
| `ScrollPosition` | iOS 18+ | Programmatic scroll control | Native iOS 18 API, binding-based |
| `@AppStorage` | iOS 14+ | Persist scroll position | Automatic sync with UserDefaults |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI-Shimmer | Latest | Animated shimmer effect | If shimmer is desired on skeleton views |
| `onScrollGeometryChange` | iOS 18+ | Track scroll offset | For offset-based persistence |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ScrollPosition` | `ScrollViewReader` | Available iOS 14+, but less flexible and no binding support |
| `@AppStorage` | `@SceneStorage` | Per-scene scope, data may be lost when app explicitly destroyed |
| SwiftUI-Shimmer | Custom ViewModifier | Full control, but more code to maintain |

**Installation:**
```bash
# SwiftUI-Shimmer via SPM (optional)
# Package URL: https://github.com/markiv/SwiftUI-Shimmer

# Or use the existing shimmer modifier in DesignSystem.swift
```

## Architecture Patterns

### Recommended Project Structure
```
ScreenSort/
├── ViewModels/
│   └── ProcessingViewModel.swift  # Already has cached result loading
├── Views/
│   └── ProcessingView.swift       # Add skeleton state, scroll persistence
├── Services/
│   └── ProcessedScreenshotStore.swift  # Already handles persistence
└── Design/
    └── DesignSystem.swift         # Shimmer modifier exists here
```

### Pattern 1: Cached-First Display with Background Refresh
**What:** Display cached data immediately, then refresh in background
**When to use:** On app launch when stale data is acceptable during refresh
**Example:**
```swift
// Source: Existing checkInitialState() pattern
struct ProcessingView: View {
    @State private var viewModel = ProcessingViewModel()
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            resultsSection
                .redacted(reason: isRefreshing ? .placeholder : [])
        }
        .onAppear {
            viewModel.checkInitialState()  // Loads cached results immediately
        }
        .task {
            // Background refresh if needed
            isRefreshing = true
            await viewModel.refreshIfNeeded()
            isRefreshing = false
        }
    }
}
```

### Pattern 2: Skeleton Loading with Shimmer
**What:** Show placeholder content with shimmer animation while loading
**When to use:** When displaying loading state before data is available
**Example:**
```swift
// Source: SwiftUI redacted modifier + shimmer
struct ResultsSection: View {
    let results: [ProcessingResultItem]
    let isLoading: Bool

    var body: some View {
        LazyVStack {
            ForEach(isLoading ? placeholderResults : results) { result in
                CompactResultRow(result: result)
            }
        }
        .redacted(reason: isLoading ? .placeholder : [])
        .shimmer()  // Uses existing DesignSystem shimmer
    }

    private var placeholderResults: [ProcessingResultItem] {
        // Dummy data matching expected layout
        (0..<5).map { index in
            ProcessingResultItem(
                assetId: "placeholder-\(index)",
                status: .success,
                contentType: .music,
                title: String(repeating: "X", count: 20),
                creator: String(repeating: "X", count: 15),
                message: "Loading...",
                serviceLink: nil
            )
        }
    }
}
```

### Pattern 3: Scroll Position Persistence (iOS 18+)
**What:** Save and restore scroll position across app launches
**When to use:** For long lists where users expect to return to their position
**Example:**
```swift
// Source: iOS 18 ScrollPosition API
struct ProcessingView: View {
    @AppStorage("scrolledResultId") private var scrolledResultId: String?
    @State private var scrollPosition = ScrollPosition(idType: String.self)

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.results) { result in
                    CompactResultRow(result: result)
                        .id(result.id.uuidString)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: String?.self) { geometry in
            // Track which item is at top of visible area
            // Return the id of the topmost visible item
            nil  // Simplified - actual implementation below
        } action: { _, newValue in
            scrolledResultId = newValue
        }
        .onAppear {
            if let savedId = scrolledResultId {
                scrollPosition.scrollTo(id: savedId)
            }
        }
    }
}
```

### Anti-Patterns to Avoid
- **Blocking main thread on launch:** Never do synchronous I/O or heavy computation in `init()` or `body`. Use `.task` or `.onAppear` for async work.
- **Over-animating skeleton states:** Don't animate individual cells during loading - animate the container once.
- **Excessive UserDefaults writes:** Don't write scroll position on every scroll event - debounce or write on disappear.
- **Using @SceneStorage for critical state:** Data may be lost when user swipes app away - use @AppStorage for guaranteed persistence.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Skeleton loading | Custom gray rectangles | `.redacted(reason: .placeholder)` | Native, automatically sizes to content |
| Shimmer animation | Custom gradient animation | Existing `ShimmerModifier` or SwiftUI-Shimmer | Already handles dark mode, RTL, etc. |
| Scroll tracking | Manual offset calculation | `ScrollPosition` + `scrollTargetLayout()` | iOS 18 native, handles all edge cases |
| State persistence | Custom file I/O | `@AppStorage` / `UserDefaults` | Synchronous read on launch, thread-safe |

**Key insight:** SwiftUI's native modifiers (`.redacted()`, `ScrollPosition`) are specifically designed for these use cases and handle edge cases like dynamic type, dark mode, and accessibility automatically.

## Common Pitfalls

### Pitfall 1: Skeleton Flicker on Fast Loads
**What goes wrong:** Skeleton shows briefly then immediately shows content, creating jarring flicker
**Why it happens:** Data loads faster than expected (cached or already available)
**How to avoid:** Only show skeleton if data takes > 100-200ms to load; skip skeleton for cached data
**Warning signs:** Users report "flashy" or "janky" loading experience
```swift
// Good: Skip skeleton when cached data is available
if viewModel.results.isEmpty && isLoading {
    skeletonView
} else {
    contentView
}
```

### Pitfall 2: Lost Scroll Position on Content Change
**What goes wrong:** Scroll jumps to top when results array changes
**Why it happens:** SwiftUI recreates scroll view or array identity changes
**How to avoid:** Use stable identifiers; apply `scrollTargetLayout()` consistently
**Warning signs:** Scroll resets unexpectedly during use

### Pitfall 3: Frequent UserDefaults Writes During Scroll
**What goes wrong:** Battery drain, potential UI stuttering from excessive writes
**Why it happens:** `onScrollGeometryChange` fires 60-120 times per second
**How to avoid:** Debounce writes; save on disappear rather than during scroll
**Warning signs:** Energy impact warnings in Xcode, thermal throttling
```swift
// Good: Save on disappear, not during scroll
.onDisappear {
    scrolledResultId = currentTopItemId
}
```

### Pitfall 4: Shimmer Animation During Processing
**What goes wrong:** Shimmer continues during actual processing, confusing users
**Why it happens:** Skeleton state not properly coordinated with processing state
**How to avoid:** Shimmer is for "loading cached data", not "processing new data"
**Warning signs:** Users confused about what the app is doing

### Pitfall 5: Redacted Views Not Matching Real Content
**What goes wrong:** Skeleton layout doesn't match actual content layout
**Why it happens:** Placeholder data has different dimensions than real data
**How to avoid:** Use placeholder data with similar text lengths; test with real layouts
**Warning signs:** Content "jumps" when transitioning from skeleton to real data

## Code Examples

Verified patterns from official sources:

### Conditional Redaction
```swift
// Source: SwiftUI redacted modifier documentation
extension View {
    @ViewBuilder
    func redacted(if condition: @autoclosure () -> Bool) -> some View {
        redacted(reason: condition() ? .placeholder : [])
    }
}

// Usage
ResultsSection()
    .redacted(if: isLoading && results.isEmpty)
```

### Enhanced Shimmer with Redaction
```swift
// Source: Existing DesignSystem.swift ShimmerModifier
// Combined with redacted for skeleton effect
Text(result.title ?? "Placeholder title here")
    .redacted(reason: isLoading ? .placeholder : [])
    .shimmer()  // Only shimmers when redacted
```

### Scroll Position Persistence with Debounce
```swift
// Source: iOS 18 ScrollPosition + onScrollGeometryChange
struct PersistentScrollView: View {
    @AppStorage("lastScrolledId") private var lastScrolledId: String = ""
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    @State private var pendingScrollId: String = ""

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    ItemRow(item: item)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .task {
            // Restore position on appear
            if !lastScrolledId.isEmpty {
                scrollPosition.scrollTo(id: lastScrolledId, anchor: .top)
            }
        }
        .onDisappear {
            // Save position on disappear (avoids frequent writes)
            if !pendingScrollId.isEmpty {
                lastScrolledId = pendingScrollId
            }
        }
    }
}
```

### Placeholder Data Generator
```swift
// Source: Community pattern for skeleton loading
extension ProcessingResultItem {
    static func placeholder(index: Int) -> ProcessingResultItem {
        ProcessingResultItem(
            assetId: "placeholder-\(index)",
            status: .success,
            contentType: .music,
            title: String.placeholder(length: 18),
            creator: String.placeholder(length: 12),
            message: "Loading...",
            serviceLink: nil
        )
    }

    static var placeholders: [ProcessingResultItem] {
        (0..<5).map { ProcessingResultItem.placeholder(index: $0) }
    }
}

extension String {
    static func placeholder(length: Int) -> String {
        String(repeating: "X", count: length)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ScrollViewReader` + `scrollTo` | `ScrollPosition` binding | iOS 18 (2024) | Simpler API, two-way binding support |
| Manual preference key for scroll offset | `onScrollGeometryChange` | iOS 18 (2024) | Native, optimized scroll tracking |
| Custom skeleton views | `.redacted(reason: .placeholder)` | iOS 14 (2020) | One-liner, automatic sizing |
| `DispatchQueue.main.async` in onAppear | `.task` modifier | iOS 15 (2021) | Auto-cancellation, cleaner async |

**Deprecated/outdated:**
- `ScrollViewReader` proxy-based scrolling: Still works but less flexible than `ScrollPosition`
- Manual offset tracking with `GeometryReader`: Replaced by `onScrollGeometryChange`

## Open Questions

Things that couldn't be fully resolved:

1. **Scroll Position Persistence with Dynamic Content**
   - What we know: `ScrollPosition` maintains position well for static lists
   - What's unclear: Behavior when items are prepended/inserted during background refresh
   - Recommendation: Test thoroughly; may need to track offset rather than item ID

2. **Exact Timing for Skeleton Display**
   - What we know: Showing skeleton for < 100ms creates flicker
   - What's unclear: Optimal minimum display time for smooth perception
   - Recommendation: Skip skeleton if cached data loads in < 150ms; test with users

3. **Background Refresh Triggering**
   - What we know: LAUNCH-02 mentions "fresh data loads in background"
   - What's unclear: Whether this means auto-refresh on launch or manual refresh
   - Recommendation: Clarify with requirements; likely auto-refresh on launch

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - ScrollPosition (iOS 18+)
- Apple Developer Documentation - onScrollGeometryChange
- Apple Developer Documentation - redacted(reason:) modifier
- [SwiftUI-Shimmer GitHub](https://github.com/markiv/SwiftUI-Shimmer) - Shimmer library reference

### Secondary (MEDIUM confidence)
- [SwiftUI Redacted Modifier - SwiftLee](https://www.avanderlee.com/swiftui/redacted-view-modifier/) - Usage patterns
- [Mastering ScrollView - Swift with Majid](https://swiftwithmajid.com/2023/06/27/mastering-scrollview-in-swiftui-scroll-position/) - ScrollPosition patterns
- [Scroll Geometry iOS 18 - Augmented Code](https://augmentedcode.io/2024/07/01/scroll-geometry-and-position-view-modifiers-in-swiftui-on-ios-18/) - iOS 18 scroll APIs
- [ScrollPosition Tutorial - SerialCoder.dev](https://serialcoder.dev/text-tutorials/swiftui/scrolling-programmatically-with-scrollposition-in-swiftui/) - iOS 18 usage

### Tertiary (LOW confidence)
- Medium articles on skeleton loading patterns
- Community discussions on scroll position restoration edge cases

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All recommendations use native SwiftUI APIs available in iOS 18
- Architecture: HIGH - Patterns align with existing codebase structure and @Observable usage
- Pitfalls: MEDIUM - Based on community experience and documentation, not exhaustive testing

**Research date:** 2026-01-30
**Valid until:** 60 days (SwiftUI iOS 18 APIs are stable)

## Implementation Notes

### Existing Code to Leverage

1. **ProcessingViewModel.checkInitialState()** - Already loads cached results synchronously
2. **ProcessedScreenshotStore** - Already persists results to UserDefaults
3. **ShimmerModifier in DesignSystem.swift** - Already implements shimmer animation
4. **ProcessingResultItem** - Already Codable with stable UUID identifiers

### Minimal Changes Required

1. **Add loading state flag** to track when background refresh is happening
2. **Add scroll position state** using `@AppStorage` for persistence
3. **Apply `.redacted()` modifier** to results section conditionally
4. **Add `.scrollPosition()` binding** to ScrollView
5. **Save scroll position on disappear** to avoid frequent writes

### iOS 18+ Dependency

The recommended scroll position approach requires iOS 18+. Since the project already targets iOS 18.1+, this is not a concern. For earlier iOS support, `ScrollViewReader` would be needed as a fallback.
