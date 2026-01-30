# Technology Stack: iOS UX Polish

**Project:** ScreenSort UX Improvements
**Researched:** 2026-01-30
**Target:** iOS 18.1+, SwiftUI, Existing MVVM architecture

## Executive Summary

This research covers the iOS frameworks and patterns needed to add three UX improvements to ScreenSort:
1. **Instant launch with cached results** - Show previous processing results immediately on app launch
2. **Progress animation during batch processing** - Smooth, non-blocking progress UI
3. **State persistence for processed items** - Remember what was processed between launches

**Recommendation:** Use SwiftUI's native patterns (`@AppStorage` for simple state, SwiftData for structured results) combined with async/await best practices to fix the UI freeze issue. Avoid third-party libraries; iOS 17/18 SwiftUI provides everything needed.

---

## 1. Instant Launch with Cached Results

### The Pattern: Stale-While-Revalidate (SWR)

**What it is:** Display cached data immediately on launch, then refresh in the background if needed.

**Why it matters:** The current app shows a blank state on launch. Users should see their previous processing results instantly.

### Recommended Approach

**Use SwiftData for result persistence** (HIGH confidence - Apple official)

SwiftData is the right choice because:
- Processing results are structured data (not just preferences)
- Results may grow large (~100+ items)
- Need querying/filtering capability (by type, status)
- Built-in SwiftUI integration via `@Query`
- iOS 17+ required (already your minimum)

```swift
import SwiftData

@Model
final class ProcessedItem {
    var assetId: String
    var status: String  // "success", "flagged", "failed"
    var contentType: String  // "music", "movie", "book", "meme"
    var title: String?
    var creator: String?
    var message: String
    var serviceLink: String?
    var processedAt: Date

    init(from result: ProcessingResultItem) {
        self.assetId = result.assetId
        self.status = result.status.rawValue
        self.contentType = result.contentType.rawValue
        self.title = result.title
        self.creator = result.creator
        self.message = result.message
        self.serviceLink = result.serviceLink
        self.processedAt = Date()
    }
}
```

**View integration with @Query:**

```swift
struct ProcessingView: View {
    @Query(sort: \ProcessedItem.processedAt, order: .reverse)
    private var cachedResults: [ProcessedItem]

    var body: some View {
        // Show cachedResults immediately on launch
        // Replace with live results during processing
    }
}
```

### Alternative Considered: UserDefaults with JSON

**Why not:** You're already doing this for corrections. For ~100+ results with filtering needs, UserDefaults becomes slow and the whole plist loads into memory on launch.

| Approach | Pros | Cons |
|----------|------|------|
| SwiftData | Type-safe, queryable, lazy loading, SwiftUI integration | Slightly more setup |
| UserDefaults/JSON | Simple, already familiar | Memory overhead, no querying, no lazy loading |

**Verdict:** SwiftData. The structured nature of processing results makes it the right tool.

---

## 2. Progress Animation During Batch Processing

### Current Problem

The app freezes during processing because heavy work runs on the `@MainActor`. The existing `ProcessingViewModel` is marked with `@Observable` and `@MainActor`, which means ALL its async work inherits the main thread context.

From your code:
```swift
@MainActor
@Observable
final class ProcessingViewModel {
    // All async work runs on main thread!
}
```

### The Fix: Move Work Off MainActor

**Pattern 1: Use `nonisolated` functions** (HIGH confidence - Apple pattern)

```swift
@MainActor
@Observable
final class ProcessingViewModel {
    // UI state stays on MainActor
    var isProcessing = false
    var processingProgress: (current: Int, total: Int) = (0, 0)

    // Heavy work moved off MainActor
    private nonisolated func performOCR(asset: PHAsset) async throws -> [TextObservation] {
        // This runs on background thread
        return try await ocrService.recognizeText(from: asset)
    }

    func processNow() async {
        isProcessing = true

        for (index, asset) in screenshots.enumerated() {
            // Update UI (on MainActor)
            processingProgress = (index + 1, screenshots.count)

            // Heavy work (off MainActor)
            let observations = try await performOCR(asset: asset)

            // Back to MainActor for state update
            results.append(processResult)
        }

        isProcessing = false
    }
}
```

**Pattern 2: Dedicated processing actor** (HIGH confidence - Swift Concurrency best practice)

```swift
actor ProcessingActor {
    private let ocrService: OCRServiceProtocol
    private let classifier: ScreenshotClassifierProtocol

    func processScreenshot(_ asset: PHAsset) async throws -> ProcessingResultItem {
        // All heavy work isolated to this actor
        let observations = try await ocrService.recognizeText(from: asset)
        let type = await classifier.classifyWithAI(textObservations: observations)
        // ... extraction logic
        return result
    }
}

@MainActor
@Observable
final class ProcessingViewModel {
    private let processor = ProcessingActor()

    func processNow() async {
        for asset in screenshots {
            // UI update (MainActor)
            processingProgress.current += 1

            // Heavy work (ProcessingActor - background)
            let result = try await processor.processScreenshot(asset)

            // Store result (MainActor)
            results.append(result)
        }
    }
}
```

### Progress UI Components

**SwiftUI ProgressView** (HIGH confidence - Apple official)

Your current `ProgressRing` is good. For the linear progress bar, use native `ProgressView`:

```swift
// Determinate progress (what you need)
ProgressView("Processing...", value: Double(current), total: Double(total))
    .progressViewStyle(.linear)
    .tint(Color(hex: "6366F1"))

// Or keep your custom ProgressRing - it's already well-implemented
```

**Key insight:** The progress bar isn't the problem. The UI freeze is caused by blocking the MainActor, not by the progress component itself.

### What NOT to Do

**Avoid `Task.detached` unless necessary** (MEDIUM confidence)

While `Task.detached` moves work off MainActor, it:
- Breaks structured concurrency (no automatic cancellation)
- Loses task-local values
- Harder to reason about

Prefer `nonisolated` functions or dedicated actors instead.

---

## 3. Skeleton/Placeholder Loading States

### Recommended: SwiftUI `.redacted()` + Custom Shimmer

**Pattern:** Show skeleton version of results while loading (HIGH confidence - iOS 14+)

```swift
struct ResultsSection: View {
    let results: [ProcessingResultItem]
    let isLoading: Bool

    var body: some View {
        if isLoading && results.isEmpty {
            // Show skeleton placeholders
            ForEach(0..<5, id: \.self) { _ in
                ResultRowPlaceholder()
                    .redacted(reason: .placeholder)
                    .shimmering()
            }
        } else {
            ForEach(results) { result in
                CompactResultRow(result: result)
            }
        }
    }
}
```

**Shimmer modifier** (no external dependency needed):

```swift
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }
}
```

### Alternative: SkeletonUI Package

**Why not:** Adds external dependency for something achievable in ~20 lines of SwiftUI. The `.redacted()` modifier plus a shimmer effect is native and sufficient.

### ContentUnavailableView for Empty States

**Use for:** When there are no results yet (HIGH confidence - iOS 17+)

```swift
if results.isEmpty && !isProcessing {
    ContentUnavailableView(
        "No Screenshots Processed",
        systemImage: "photo.stack",
        description: Text("Tap Process to scan your photo library")
    )
}
```

---

## 4. State Persistence

### What to Persist

| Data | Storage | Rationale |
|------|---------|-----------|
| Processing results | SwiftData | Structured, queryable, can be large |
| User corrections | UserDefaults (keep current) | Already implemented, working well |
| Last processing date | `@AppStorage` | Simple timestamp |
| Processing preferences | `@AppStorage` | User settings |

### SwiftData Setup

**App configuration:**

```swift
@main
struct ScreenSortApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ProcessedItem.self])
    }
}
```

**Saving results:**

```swift
@Environment(\.modelContext) private var modelContext

func saveResult(_ result: ProcessingResultItem) {
    let item = ProcessedItem(from: result)
    modelContext.insert(item)
    // SwiftData auto-saves on app background
}
```

### Complement with @AppStorage

For simple flags and preferences:

```swift
@AppStorage("lastProcessingDate") private var lastProcessingDate: Date?
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
@AppStorage("showProcessedCount") private var showProcessedCount = true
```

---

## Implementation Priority

### Phase 1: Fix the Freeze (Critical)
1. Extract heavy processing into `nonisolated` functions
2. Keep UI updates on MainActor
3. Test with 100+ screenshots

### Phase 2: Add Persistence (High)
1. Add SwiftData model for ProcessedItem
2. Load cached results on launch
3. Save results after each processing run

### Phase 3: Polish Loading States (Medium)
1. Add shimmer placeholders during initial load
2. Add ContentUnavailableView for empty state
3. Improve progress animations

---

## Anti-Patterns to Avoid

### 1. Using DispatchQueue.main.async

**Wrong:**
```swift
DispatchQueue.main.async {
    self.progress = newValue
}
```

**Right:**
```swift
await MainActor.run {
    self.progress = newValue
}
```

**Why:** Mixing GCD with Swift Concurrency leads to subtle bugs and makes code harder to reason about.

### 2. Force-unwrapping @Query results

**Wrong:**
```swift
@Query var items: [ProcessedItem]
// Assuming items is never empty
let first = items.first!
```

**Right:**
```swift
if let first = items.first {
    // Handle
} else {
    ContentUnavailableView(...)
}
```

### 3. Blocking MainActor with synchronous work

**Wrong:**
```swift
@MainActor
func process() async {
    for item in largeArray {
        heavySyncWork(item)  // Blocks UI!
    }
}
```

**Right:**
```swift
@MainActor
func process() async {
    for item in largeArray {
        await processInBackground(item)  // Yields to UI
    }
}

nonisolated func processInBackground(_ item: Item) async {
    heavySyncWork(item)
}
```

---

## Confidence Assessment

| Component | Confidence | Source |
|-----------|------------|--------|
| SwiftData for results | HIGH | Apple documentation, WWDC sessions |
| nonisolated pattern | HIGH | Apple concurrency docs, Swift forums |
| .redacted() + shimmer | HIGH | SwiftUI documentation, community verified |
| @AppStorage for settings | HIGH | Apple documentation |
| ContentUnavailableView | HIGH | iOS 17+ official API |
| Actor isolation patterns | HIGH | Swift Evolution, Apple docs |

---

## Sources

### Official Documentation
- [SwiftData | Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata)
- [ProgressView | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/progressview)
- [Persistent Storage | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/persistent-storage)

### Verified Community Sources
- [SwiftUI Tasks Blocking the MainActor | Use Your Loaf](https://useyourloaf.com/blog/swiftui-tasks-blocking-the-mainactor/)
- [MainActor usage in Swift | SwiftLee](https://www.avanderlee.com/swift/mainactor-dispatch-main-thread/)
- [ContentUnavailableView | SwiftLee](https://www.avanderlee.com/swiftui/contentunavailableview-handling-empty-states/)
- [SwiftUI Shimmer Loading Animation | Medium](https://medium.com/@Ajay_iOS/swiftui-micro-interaction-shimmer-placeholder-animation-in-10-lines-61348d380863)
- [How to show progress on a task | Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-show-progress-on-a-task-using-progressview)
- [SwiftUI Data Caching Strategies | DEV Community](https://dev.to/sebastienlato/swiftui-data-caching-strategies-memory-disk-network-n08)
- [The Art of SwiftData in 2025 | Medium](https://medium.com/@matgnt/the-art-of-swiftdata-in-2025-from-scattered-pieces-to-a-masterpiece-1fd0cefd8d87)
