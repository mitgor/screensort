# Architecture Patterns: SwiftUI UX Improvements

**Domain:** iOS SwiftUI app with MVVM architecture
**Researched:** 2026-01-30
**Confidence:** HIGH (verified with official documentation and authoritative sources)

## Executive Summary

This research addresses three UX improvements for ScreenSort:
1. **Cached UI state** that restores instantly on launch
2. **Non-blocking batch processing** with progress updates
3. **Persistent storage** for tracking processed items

All patterns integrate naturally with ScreenSort's existing `@Observable` MVVM architecture. The recommended approach uses native SwiftUI mechanisms (`@SceneStorage`, `@AppStorage`) combined with structured concurrency (`TaskGroup`, `AsyncStream`) rather than introducing new frameworks.

---

## Current Architecture Analysis

### Existing Components

| Component | Current State | Integration Point |
|-----------|---------------|-------------------|
| `ProcessingViewModel` | `@Observable`, `@MainActor` | Primary integration target |
| `CorrectionStore` | `UserDefaults` via singleton | Pattern to extend |
| `ScreenSortApp` | Minimal, just `WindowGroup` | Add state restoration |
| `ContentView` | Uses `@AppStorage` for onboarding | Extend for results cache |
| `ProcessingView` | `@State` for ViewModel | Convert to scene-aware |

### Current Processing Flow (Sequential)

```swift
// Current: Sequential for loop blocks UI
for (index, asset) in screenshots.enumerated() {
    processingProgress = (index + 1, screenshots.count)
    let result = await processScreenshot(asset: asset, playlistId: playlistId)
    results.append(result)
}
```

**Problem:** Each screenshot processes fully before the next begins. UI updates happen between iterations but the main actor is still blocked during each `processScreenshot` call.

---

## Pattern 1: Cached UI State Restoration

### Recommended Approach: @SceneStorage + @AppStorage Combination

**Confidence:** HIGH (verified via [Swift with Majid](https://swiftwithmajid.com/2022/03/10/state-restoration-in-swiftui/) and Apple documentation)

Use `@SceneStorage` for transient UI state and `@AppStorage` for persistent results cache.

### Where It Fits in Existing MVVM

```
ScreenSortApp.swift          ProcessingView.swift         ProcessingViewModel.swift
      |                            |                              |
      v                            v                              v
WindowGroup               @SceneStorage for:            @Observable state:
  .handlesExternalEvents  - isProcessing (recovery)     - results array
                          - lastTab                      - progress tuple

                          @AppStorage for:              New: Codable ResultsCache
                          - hasCompletedOnboarding      that syncs to UserDefaults
                          (already exists)
```

### Implementation Pattern

**1. Results Cache (Extend CorrectionStore Pattern)**

```swift
/// Persists processing results for instant restoration
/// Follows existing CorrectionStore pattern
final class ResultsCache: Sendable {
    private static let storageKey = "ScreenSort.ProcessingResults"
    static let shared = ResultsCache()

    func saveResults(_ results: [ProcessingResultItem]) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func loadResults() -> [ProcessingResultItem] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let results = try? JSONDecoder().decode([ProcessingResultItem].self, from: data)
        else { return [] }
        return results
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
```

**2. Make ProcessingResultItem Codable**

```swift
struct ProcessingResultItem: Identifiable, Sendable, Codable {
    let id: UUID
    let assetId: String
    let status: Status
    let contentType: ScreenshotType
    let title: String?
    let creator: String?
    let message: String
    let serviceLink: String?

    enum Status: String, Sendable, Codable {
        case success, flagged, failed
    }
}
```

**3. ViewModel Integration**

```swift
@MainActor
@Observable
final class ProcessingViewModel {
    var results: [ProcessingResultItem] = [] {
        didSet {
            // Auto-persist on change (debounced in production)
            ResultsCache.shared.saveResults(results)
        }
    }

    func restoreCachedState() {
        results = ResultsCache.shared.loadResults()
    }
}
```

**4. Scene-Level Restoration**

```swift
struct ProcessingView: View {
    @State private var viewModel = ProcessingViewModel()
    @SceneStorage("wasProcessing") private var wasProcessing = false

    var body: some View {
        // ... existing view code
        .onAppear {
            viewModel.restoreCachedState()
            if wasProcessing {
                // Show "processing was interrupted" UI
            }
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            wasProcessing = isProcessing
        }
    }
}
```

### Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| @SceneStorage | Automatic, per-scene, no code needed | Limited to simple types, no arrays |
| @AppStorage | Simple, persists across launches | Global, not scene-specific |
| UserDefaults (manual) | Full control, complex types via Codable | More code, manual sync |
| **Recommended: Hybrid** | Best of both worlds | Slightly more complexity |

---

## Pattern 2: Non-Blocking Batch Processing

### Recommended Approach: TaskGroup with AsyncStream for Progress

**Confidence:** HIGH (verified via [SwiftLee](https://www.avanderlee.com/concurrency/task-groups-in-swift/) and [Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/async-stream))

### Current Problem

The existing `for` loop processes sequentially. Even though it's `async`, each iteration completes before the next begins, and UI updates only happen between iterations.

### Solution: Parallel Processing with Controlled Concurrency

```swift
func processNow() async {
    isProcessing = true
    results = []

    // ... setup code ...

    // Process in parallel batches with progress stream
    let progressStream = processScreenshotsInParallel(
        screenshots: screenshots,
        playlistId: playlistId,
        maxConcurrency: 4  // Tune based on API rate limits
    )

    for await update in progressStream {
        switch update {
        case .progress(let current, let total):
            processingProgress = (current, total)
        case .result(let item):
            results.append(item)
        case .completed:
            break
        }
    }

    isProcessing = false
}
```

### AsyncStream Implementation

```swift
enum ProcessingUpdate {
    case progress(current: Int, total: Int)
    case result(ProcessingResultItem)
    case completed
}

func processScreenshotsInParallel(
    screenshots: [PHAsset],
    playlistId: String,
    maxConcurrency: Int
) -> AsyncStream<ProcessingUpdate> {
    AsyncStream { continuation in
        Task {
            var completed = 0
            let total = screenshots.count

            // Process in batches to control concurrency
            for batch in screenshots.chunked(into: maxConcurrency) {
                await withTaskGroup(of: ProcessingResultItem.self) { group in
                    for asset in batch {
                        group.addTask {
                            await self.processScreenshot(asset: asset, playlistId: playlistId)
                        }
                    }

                    for await result in group {
                        completed += 1
                        continuation.yield(.progress(current: completed, total: total))
                        continuation.yield(.result(result))
                    }
                }
            }

            continuation.yield(.completed)
            continuation.finish()
        }
    }
}

// Helper extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### Why TaskGroup + AsyncStream

| Approach | UI Responsiveness | Progress Accuracy | Complexity |
|----------|-------------------|-------------------|------------|
| Sequential for loop | Poor (blocked) | Good | Low |
| Pure TaskGroup | Good | Only at batch boundaries | Medium |
| **TaskGroup + AsyncStream** | Excellent | Real-time per-item | Medium |
| Detached Tasks | Good | Complex to coordinate | High |

### Concurrency Considerations

**Rate Limiting:** YouTube API has quotas. Set `maxConcurrency` to 2-4 to avoid hitting rate limits.

```swift
// Conservative for API-heavy processing
let maxConcurrency = 2

// More aggressive for local-only processing (OCR, classification)
let maxConcurrency = ProcessInfo.processInfo.activeProcessorCount
```

### Progress Update Throttling

**Critical:** Updating SwiftUI state in tight loops can cause performance issues.

```swift
// BAD: Updates UI on every iteration
for await update in progressStream {
    processingProgress = (current, total)  // Too frequent!
}

// GOOD: Throttle to meaningful changes
private var lastProgressUpdate = Date.distantPast

for await update in progressStream {
    if case .progress(let current, let total) = update {
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) > 0.1 {  // Max 10 updates/sec
            processingProgress = (current, total)
            lastProgressUpdate = now
        }
    }
}
```

---

## Pattern 3: Persistent Storage for Processed Items

### Recommended Approach: UserDefaults with Codable (Extend Existing Pattern)

**Confidence:** HIGH (verified via [Donny Wals](https://www.donnywals.com/storage-options-on-ios-compared/) and multiple authoritative sources)

### Storage Options Comparison

| Option | Best For | ScreenSort Fit |
|--------|----------|----------------|
| **UserDefaults** | Key-value, < 1MB, fast reads | **Best fit** - asset IDs are small |
| File Storage | Large blobs, images | Overkill for ID tracking |
| SwiftData | Complex queries, relationships | Overkill, requires iOS 17+ (already met) |
| Core Data | Complex queries, legacy | More complex than needed |

### Why UserDefaults is Right for ScreenSort

1. **Data is small:** Just asset local identifiers (strings)
2. **Queries are simple:** "Has this asset been processed?" (O(1) lookup)
3. **Already used:** `CorrectionStore` uses this pattern
4. **No new dependencies:** Works on iOS 18.1+ (already required)

### Implementation: ProcessedAssetsStore

```swift
/// Tracks which assets have been processed
/// Follows existing CorrectionStore pattern
final class ProcessedAssetsStore: Sendable {
    private static let storageKey = "ScreenSort.ProcessedAssets"
    static let shared = ProcessedAssetsStore()

    private init() {}

    // MARK: - Public API

    func markAsProcessed(_ assetId: String) {
        var processed = loadProcessedSet()
        processed.insert(assetId)
        saveProcessedSet(processed)
    }

    func isProcessed(_ assetId: String) -> Bool {
        loadProcessedSet().contains(assetId)
    }

    func unprocessedAssets(from assets: [PHAsset]) -> [PHAsset] {
        let processed = loadProcessedSet()
        return assets.filter { !processed.contains($0.localIdentifier) }
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Private

    private func loadProcessedSet() -> Set<String> {
        guard let array = UserDefaults.standard.stringArray(forKey: Self.storageKey) else {
            return []
        }
        return Set(array)
    }

    private func saveProcessedSet(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: Self.storageKey)
    }
}
```

### Integration with Existing Filter Logic

Current code filters by caption prefix:

```swift
// Current approach
let screenshots = allScreenshots.filter { asset in
    guard let caption = photoService.getCaption(for: asset) else { return true }
    return !caption.hasPrefix(captionPrefix)
}
```

New approach with ProcessedAssetsStore:

```swift
// New approach - faster, doesn't require loading captions
let screenshots = ProcessedAssetsStore.shared.unprocessedAssets(from: allScreenshots)
```

**Benefit:** Caption checking requires Photos framework calls; Set lookup is O(1).

### When to Use SwiftData Instead

Consider SwiftData if ScreenSort evolves to need:
- Querying results by date range
- Filtering by multiple criteria (type + status + date)
- Relationships between entities
- CloudKit sync

For current needs, UserDefaults is simpler and sufficient.

---

## Component Boundaries

### Updated Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          ScreenSortApp                               │
│  - WindowGroup with scene state                                      │
│  - ScenePhase monitoring                                             │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ProcessingView                               │
│  - @SceneStorage for UI state (wasProcessing, selectedTab)          │
│  - @State for ViewModel                                              │
│  - Observes ViewModel for reactive updates                           │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ProcessingViewModel                             │
│  @Observable, @MainActor                                             │
│                                                                      │
│  State:                          Methods:                            │
│  - results: [ProcessingResultItem]   - processNow() async            │
│  - processingProgress: (Int, Int)    - restoreCachedState()          │
│  - isProcessing: Bool                - processInParallel() -> Stream │
│                                                                      │
│  Integrates with:                                                    │
│  - ResultsCache (new)                                                │
│  - ProcessedAssetsStore (new)                                        │
│  - Existing services (unchanged)                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
┌───────────────────────┐ ┌─────────────────┐ ┌──────────────────────┐
│    ResultsCache       │ │ProcessedAssets  │ │  CorrectionStore     │
│    (NEW)              │ │Store (NEW)      │ │  (EXISTS)            │
│                       │ │                 │ │                      │
│ - saveResults()       │ │- markProcessed()│ │ - saveCorrection()   │
│ - loadResults()       │ │- isProcessed()  │ │ - loadCorrection()   │
│ - clear()             │ │- unprocessed()  │ │ - markAsApplied()    │
│                       │ │                 │ │                      │
│ Key: ProcessingResults│ │Key: Processed   │ │ Key: UserCorrections │
│      (UserDefaults)   │ │     Assets      │ │      (UserDefaults)  │
└───────────────────────┘ └─────────────────┘ └──────────────────────┘
```

### Data Flow

```
App Launch:
  1. ProcessingView.onAppear
  2. → viewModel.restoreCachedState()
  3. → ResultsCache.loadResults()
  4. → results populated instantly
  5. → UI renders cached results

Process Now:
  1. User taps "Process Screenshots"
  2. → viewModel.processNow()
  3. → ProcessedAssetsStore.unprocessedAssets(from:)
  4. → processInParallel() returns AsyncStream
  5. → for await update in stream { ... }
  6. → Each result: results.append() triggers UI update
  7. → ResultsCache auto-saves on results didSet
  8. → ProcessedAssetsStore.markAsProcessed() for each

App Background:
  1. ScenePhase changes to .background
  2. → wasProcessing saved via @SceneStorage
  3. → ResultsCache already persisted (didSet)

App Killed & Relaunched:
  1. Same as App Launch
  2. If wasProcessing == true, show recovery UI
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing PHAsset Objects

**What:** Trying to persist `PHAsset` objects directly
**Why bad:** PHAsset is not Codable; local identifiers can change
**Instead:** Store `localIdentifier` strings, re-fetch assets when needed

### Anti-Pattern 2: Updating UI on Every Progress Tick

**What:** `processingProgress = (i, total)` in tight loop
**Why bad:** Can slow processing by 500% (per [Khanlou](https://khanlou.com/2021/10/download-progress-with-awaited-network-tasks/))
**Instead:** Throttle updates to 10 per second maximum

### Anti-Pattern 3: Using @Published with @Observable

**What:** Mixing `@Published` properties in `@Observable` class
**Why bad:** Redundant, causes double-updates
**Instead:** Plain `var` in `@Observable` classes auto-publishes

### Anti-Pattern 4: Detached Tasks for Parallel Processing

**What:** Using `Task.detached` for parallel screenshot processing
**Why bad:** Loses structured concurrency benefits, harder to cancel
**Instead:** Use `TaskGroup` with controlled concurrency

---

## Integration Checklist

### Phase 1: State Caching (Low Risk)

- [ ] Make `ProcessingResultItem` Codable
- [ ] Create `ResultsCache` following `CorrectionStore` pattern
- [ ] Add `restoreCachedState()` to ViewModel
- [ ] Call on `.onAppear` in ProcessingView
- [ ] Add `didSet` auto-save on `results`

### Phase 2: Processed Tracking (Low Risk)

- [ ] Create `ProcessedAssetsStore`
- [ ] Replace caption-based filtering with store lookup
- [ ] Mark assets as processed after success
- [ ] Handle edge case: correction changes should clear processed status

### Phase 3: Parallel Processing (Medium Risk)

- [ ] Add `AsyncStream` progress pattern
- [ ] Implement `processInParallel()` with TaskGroup
- [ ] Add throttled progress updates
- [ ] Test with rate-limited APIs (YouTube)
- [ ] Add cancellation support

---

## Sources

### HIGH Confidence (Official/Authoritative)

- [Apple: Restoring Your App's State with SwiftUI](https://developer.apple.com/documentation/swiftui/restoring-your-app-s-state-with-swiftui)
- [Apple: TaskGroup Documentation](https://developer.apple.com/documentation/swift/taskgroup)
- [Apple: WWDC22 Background Tasks in SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10142/)

### MEDIUM Confidence (Verified Community Sources)

- [Swift with Majid: State Restoration in SwiftUI](https://swiftwithmajid.com/2022/03/10/state-restoration-in-swiftui/)
- [SwiftLee: Task Groups in Swift](https://www.avanderlee.com/concurrency/task-groups-in-swift/)
- [SwiftLee: MainActor Usage](https://www.avanderlee.com/swift/mainactor-dispatch-main-thread/)
- [Donny Wals: Storage Options Compared](https://www.donnywals.com/storage-options-on-ios-compared/)
- [Jacob's Tech Tavern: AsyncStream](https://blog.jacobstechtavern.com/p/async-stream)
- [Khanlou: Download Progress with Awaited Network Tasks](https://khanlou.com/2021/10/download-progress-with-awaited-network-tasks/)

### Additional References

- [Kodeco: State Restoration in SwiftUI](https://www.kodeco.com/34862236-state-restoration-in-swiftui)
- [Medium: Concurrency in Swift 6](https://medium.com/@amir.daliri/concurrency-in-swift-6-6f2b960065f1)
- [Medium: iOS Persistence Storage Comparison](https://medium.com/@direct.anaufal/understanding-ios-persistence-storage-userdefaults-swiftdata-and-cloudkit-2301634b15b4)
- [Livsy Code: Storage Options Comparison](https://livsycode.com/best-practices/userdefaults-vs-filemanager-vs-keychain-vs-core-data-vs-swiftdata/)
