# Domain Pitfalls: iOS UX Polish (Loading States, Progress, Persistence)

**Domain:** iOS 18.1+ SwiftUI app - UX improvements for batch processing
**Researched:** 2026-01-30
**Confidence:** HIGH (multiple authoritative sources verified)

---

## Critical Pitfalls

Mistakes that cause UI freezes, data loss, or require significant rewrites.

---

### Pitfall 1: @MainActor Task Inheritance Trap

**What goes wrong:** Tasks created with `Task { }` from SwiftUI views inherit the `@MainActor` context. Heavy synchronous work inside an `@Observable` ViewModel marked with `@MainActor` blocks the UI, causing freezes.

**Why it happens:** Developers assume `Task { }` automatically runs on a background thread. In reality, `Task.init` inherits the actor context of its caller. When called from a SwiftUI View (which runs on `@MainActor` since Xcode 16), the entire task executes on the main thread.

**Consequences:**
- UI becomes unresponsive during processing
- Watchdog may kill the app (0x8BADF00D termination)
- Users perceive app as "frozen" or "crashed"

**Code anti-pattern:**
```swift
// BAD: This blocks the main thread!
@MainActor
@Observable
final class ProcessingViewModel {
    func processNow() async {
        // This runs on MainActor because the class is @MainActor
        for asset in screenshots {
            let result = await ocrService.recognizeText(from: asset) // Heavy work
            results.append(result) // UI blocked until complete
        }
    }
}

// In SwiftUI View:
Button("Process") {
    Task { await viewModel.processNow() } // Still on MainActor!
}
```

**Prevention:**
```swift
// GOOD: Use nonisolated for heavy work
@MainActor
@Observable
final class ProcessingViewModel {
    func processNow() async {
        isProcessing = true

        // Move heavy work off MainActor
        let processedResults = await performHeavyWork(screenshots)

        // Update UI back on MainActor
        self.results = processedResults
        isProcessing = false
    }

    // Heavy work isolated from MainActor
    nonisolated private func performHeavyWork(_ assets: [PHAsset]) async -> [Result] {
        var results: [Result] = []
        for asset in assets {
            let result = await processAsset(asset)
            results.append(result)
        }
        return results
    }
}
```

**Detection (Warning signs):**
- UI freezes when "Process" button is tapped
- Progress indicators don't animate during processing
- App becomes unresponsive for several seconds
- Instruments "Hangs" tool shows main thread blocked >100ms

**Phase to address:** Phase 1 (Background Processing) - Must fix before any UX polish

**Sources:**
- [SwiftUI Tasks Blocking the MainActor](https://useyourloaf.com/blog/swiftui-tasks-blocking-the-mainactor/)
- [SwiftUI UI Freezing Fixed](https://openillumi.com/en/en-swiftui-task-ui-freeze-mainactor-fix/)
- [Suspension vs Blocking in Swift Concurrency](https://medium.com/@maatheusgois/suspension-vs-blocking-the-swift-concurrency-mindset-you-need-1dfa75ffba94)

---

### Pitfall 2: Vision OCR on Main Thread

**What goes wrong:** `VNRecognizeTextRequest` performs CPU-intensive image analysis. Running it on the main thread freezes the UI during text recognition.

**Why it happens:** Developers call Vision APIs synchronously or forget that `VNImageRequestHandler.perform()` is a blocking call that should run on a background queue.

**Consequences:**
- Multi-second UI freezes per image
- With batch processing (100+ screenshots), app appears completely frozen
- User may force-quit the app

**Code anti-pattern:**
```swift
// BAD: Blocking the main thread
func recognizeText(from asset: PHAsset) async throws -> [String] {
    let image = try await loadImage(from: asset)
    let request = VNRecognizeTextRequest()
    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request]) // BLOCKS calling thread!
    return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
}
```

**Prevention:**
```swift
// GOOD: Run Vision on background queue
func recognizeText(from asset: PHAsset) async throws -> [String] {
    let image = try await loadImage(from: asset)

    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate // or .fast for real-time

            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**Detection:**
- Instruments shows `VNImageRequestHandler.perform` on main thread
- Time Profiler shows Vision framework dominating main thread
- UI completely unresponsive during OCR phase

**Phase to address:** Phase 1 (Background Processing) - Core fix for freeze issue

**Sources:**
- [Hacking with Swift - VNRecognizeTextRequest](https://www.hackingwithswift.com/example-code/vision/how-to-use-vnrecognizetextrequests-optical-character-recognition-to-detect-text-in-an-image)
- [Vision Framework Performance](https://bendodson.com/weblog/2019/06/11/detecting-text-with-vnrecognizetextrequest-in-ios-13/)

---

### Pitfall 3: @AppStorage for Critical Persistence Data

**What goes wrong:** Using `@AppStorage` (UserDefaults) for processing results or state that must survive app termination. Data can be lost because UserDefaults persistence is not atomic.

**Why it happens:** `@AppStorage` is easy to use and works well for preferences. Developers extend its use to processing state without understanding its limitations.

**Consequences:**
- Processing results lost if app crashes or is terminated
- Inconsistent state between app launches
- Users must reprocess all screenshots repeatedly

**Code anti-pattern:**
```swift
// BAD: Critical data in @AppStorage
struct ContentView: View {
    @AppStorage("processedAssetIds") private var processedAssetIds: String = ""
    @AppStorage("lastProcessingResults") private var resultsJSON: String = ""
}
```

**Prevention:**
```swift
// GOOD: Use proper persistence for critical data
// Option 1: SwiftData (iOS 17+)
@Model
final class ProcessedScreenshot {
    var assetId: String
    var contentType: String
    var processedAt: Date
    var title: String?
    var creator: String?
}

// Option 2: File-based JSON persistence
actor ProcessingStateStore {
    private let fileURL: URL

    func save(_ results: [ProcessingResult]) async throws {
        let data = try JSONEncoder().encode(results)
        try data.write(to: fileURL, options: .atomic) // Atomic write!
    }

    func load() async throws -> [ProcessingResult] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ProcessingResult].self, from: data)
    }
}

// @AppStorage is fine for preferences only
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

**Detection:**
- Users report "app forgot my processed screenshots"
- Processing state resets after force-quit
- Data inconsistencies between launches

**Phase to address:** Phase 3 (State Persistence)

**Sources:**
- [Mastering @AppStorage in SwiftUI](https://fatbobman.com/en/posts/appstorage/)
- [@AppStorage Explained](https://www.avanderlee.com/swift/appstorage-explained/)
- [SwiftUI Data Persistence](https://medium.com/@nsuneelkumar98/swiftui-data-persistence-userdefaults-vs-appstorage-a66c41666d15)

---

### Pitfall 4: PHAsset Batch Processing Memory Blowout

**What goes wrong:** Loading full-resolution images for all screenshots into memory simultaneously causes memory pressure and crashes.

**Why it happens:** `PHAsset` references are lazy-loaded, but requesting image data for many assets at once loads them all into memory.

**Consequences:**
- Memory warnings and termination
- App crashes during batch processing
- Degraded device performance

**Code anti-pattern:**
```swift
// BAD: Loading all images into memory
func processAllScreenshots() async {
    let assets = try await fetchScreenshots() // Returns 500 assets

    // This loads ALL images into memory!
    let images = await withTaskGroup(of: UIImage?.self) { group in
        for asset in assets {
            group.addTask { await self.loadImage(from: asset) }
        }
        return await group.reduce(into: []) { $0.append($1) }
    }

    // Now process them... but we're likely already OOM
}
```

**Prevention:**
```swift
// GOOD: Process sequentially with autoreleasepool
func processAllScreenshots() async {
    let assets = try await fetchScreenshots()

    for asset in assets {
        autoreleasepool {
            // Load, process, release one at a time
            if let image = await loadImage(from: asset) {
                let result = await processImage(image)
                await updateProgress(with: result)
            }
            // Image released at end of autoreleasepool
        }
    }
}

// BETTER: Use PHCachingImageManager for thumbnails
let cachingManager = PHCachingImageManager()
cachingManager.startCachingImages(for: upcomingAssets,
                                   targetSize: thumbnailSize,
                                   contentMode: .aspectFill,
                                   options: nil)
```

**Detection:**
- Memory usage spikes during processing
- Jetsam terminations in crash logs
- Device becomes sluggish during batch operations

**Phase to address:** Phase 1 (Background Processing)

**Sources:**
- [The Photos Framework - objc.io](https://www.objc.io/issues/21-camera-and-photos/the-photos-framework/)
- [PHCachingImageManager Documentation](https://developer.apple.com/documentation/photos/phcachingimagemanager)
- [Building a Photo Gallery App - Memory Management](https://codewithchris.com/photo-gallery-app-swiftui-part-1/)

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or degraded user experience.

---

### Pitfall 5: Animation During State Changes Causing Layout Thrashing

**What goes wrong:** Animating every state change in batch processing causes excessive layout recalculations and visual stuttering.

**Why it happens:** Using `.animation()` modifier broadly or wrapping all state changes in `withAnimation` triggers animations for data changes that should be instant.

**Consequences:**
- Janky, stuttering UI during processing
- Layout thrashing as hundreds of results animate in
- Performance degradation

**Code anti-pattern:**
```swift
// BAD: Animating data changes
@Observable
class ViewModel {
    var results: [Result] = [] // Every append animates!
}

struct ProcessingView: View {
    var body: some View {
        ForEach(viewModel.results) { result in
            ResultRow(result: result)
        }
        .animation(.default, value: viewModel.results) // Animates ALL changes
    }
}
```

**Prevention:**
```swift
// GOOD: Selective animation for UI state only
struct ProcessingView: View {
    var body: some View {
        VStack {
            // Animate UI state changes
            if viewModel.isProcessing {
                ProgressSection()
                    .transition(.move(edge: .bottom))
            }

            // NO animation for data - use LazyVStack
            LazyVStack {
                ForEach(viewModel.results) { result in
                    ResultRow(result: result)
                }
            }
        }
        // Only animate specific UI state, not data
        .animation(.spring(), value: viewModel.isProcessing)
    }
}
```

**Detection:**
- CPU spikes during result updates
- Visual stuttering as results appear
- Instruments shows excessive layout passes

**Phase to address:** Phase 2 (Progress Indicators)

**Sources:**
- [Common Pitfalls from Delayed State Updates](https://fatbobman.com/en/posts/serious-issues-caused-by-delayed-state-updates-in-swiftui/)
- [Demystifying SwiftUI Animation](https://fatbobman.com/en/posts/the_animation_mechanism_of_swiftui/)

---

### Pitfall 6: Progress Updates Too Frequent

**What goes wrong:** Updating `@Published` or `@Observable` properties for every single item processed causes excessive view re-renders.

**Why it happens:** Developers update progress after each item (e.g., 500 times for 500 screenshots) without throttling.

**Consequences:**
- UI becomes sluggish
- Animation frames dropped
- Progress bar updates may cause layout recalculations

**Code anti-pattern:**
```swift
// BAD: Update progress for every item
for (index, asset) in assets.enumerated() {
    await processAsset(asset)
    await MainActor.run {
        processingProgress = (index + 1, assets.count) // 500 updates!
    }
}
```

**Prevention:**
```swift
// GOOD: Throttle progress updates
actor ProgressThrottler {
    private var lastUpdate = Date.distantPast
    private let minInterval: TimeInterval = 0.1 // Max 10 updates/sec

    func shouldUpdate() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) >= minInterval {
            lastUpdate = now
            return true
        }
        return false
    }
}

// In processing loop:
for (index, asset) in assets.enumerated() {
    await processAsset(asset)
    if await progressThrottler.shouldUpdate() {
        await MainActor.run {
            processingProgress = (index + 1, assets.count)
        }
    }
}

// Always update at completion
await MainActor.run {
    processingProgress = (assets.count, assets.count)
}
```

**Detection:**
- Progress bar updates feel "heavy"
- CPU usage high during progress updates
- Time Profiler shows frequent view body evaluations

**Phase to address:** Phase 2 (Progress Indicators)

---

### Pitfall 7: Task Not Cancelled on View Disappear

**What goes wrong:** Long-running tasks continue executing after the view is dismissed, causing memory leaks and wasted resources.

**Why it happens:** Using `Task { }` in `onAppear` without cancellation logic, or not using the `.task` modifier.

**Consequences:**
- Memory leaks (ViewModel retained by running task)
- Wasted CPU/battery on orphaned tasks
- Potential crashes if task updates deallocated view

**Code anti-pattern:**
```swift
// BAD: Task lives forever
struct ProcessingView: View {
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack { ... }
        .onAppear {
            task = Task { await viewModel.processNow() }
        }
        // No onDisappear to cancel!
    }
}
```

**Prevention:**
```swift
// GOOD: Use .task modifier (auto-cancels on disappear)
struct ProcessingView: View {
    var body: some View {
        VStack { ... }
        .task {
            await viewModel.processNow()
        }
    }
}

// GOOD: Manual cancellation if needed
struct ProcessingView: View {
    @State private var processingTask: Task<Void, Never>?

    var body: some View {
        VStack { ... }
        .onAppear {
            processingTask = Task { await viewModel.processNow() }
        }
        .onDisappear {
            processingTask?.cancel()
        }
    }
}

// In ViewModel, check for cancellation:
func processNow() async {
    for asset in assets {
        guard !Task.isCancelled else { break }
        await processAsset(asset)
    }
}
```

**Detection:**
- ViewModel `deinit` never called
- Memory usage grows with navigation
- Instruments shows retained objects

**Phase to address:** Phase 1 (Background Processing)

**Sources:**
- [Mastering Task Cancellation in SwiftUI](https://medium.com/@sebasf8/mastering-task-cancellation-in-swiftui-74cb9d5af4ff)
- [Memory Management with async/await](https://www.swiftbysundell.com/articles/memory-management-when-using-async-await/)
- [Mastering the SwiftUI task Modifier](https://fatbobman.com/en/posts/mastering_swiftui_task_modifier/)

---

### Pitfall 8: Launch Screen Caching Issues

**What goes wrong:** iOS aggressively caches launch screens. Changes to launch screen don't appear until app is deleted and reinstalled.

**Why it happens:** iOS caches launch screens in `Library/SplashBoard/` and doesn't invalidate cache on app updates.

**Consequences:**
- Old launch screen shows after updates
- Development changes don't appear in testing
- Users see inconsistent branding

**Prevention:**
```swift
// Clear launch screen cache during development
// Add to AppDelegate or App init (DEBUG only):
#if DEBUG
func clearLaunchScreenCache() {
    do {
        let launchScreenPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SplashBoard")
        if FileManager.default.fileExists(atPath: launchScreenPath.path) {
            try FileManager.default.removeItem(at: launchScreenPath)
        }
    } catch {
        print("Failed to clear launch screen cache: \(error)")
    }
}
#endif
```

**Detection:**
- Launch screen changes not visible
- Old branding appears on launch

**Phase to address:** Phase 4 (Launch Experience) - Be aware, not necessarily "fix"

**Sources:**
- [Apple Developer Forums - Launch Screen Caching](https://developer.apple.com/forums/thread/105790)
- [Fix the Cached Launch Screen Bug](https://www.theswift.dev/posts/fix-the-cached-launch-screen-image-bug-on-ios)

---

## Minor Pitfalls

Mistakes that cause annoyance but are relatively easy to fix.

---

### Pitfall 9: Skeleton/Shimmer Without Proper Shape Matching

**What goes wrong:** Skeleton loading states don't match the actual content layout, causing jarring "shift" when content loads.

**Why it happens:** Using generic rectangles instead of matching the actual view shapes.

**Prevention:**
```swift
// GOOD: Skeleton matches actual layout
struct ResultRow: View {
    let result: ProcessingResult?

    var body: some View {
        HStack {
            Circle()
                .fill(result != nil ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .redacted(reason: result == nil ? .placeholder : [])

            VStack(alignment: .leading) {
                Text(result?.title ?? "Placeholder Title Text")
                    .redacted(reason: result == nil ? .placeholder : [])
                Text(result?.subtitle ?? "Subtitle")
                    .font(.caption)
                    .redacted(reason: result == nil ? .placeholder : [])
            }
        }
        .shimmering(active: result == nil)
    }
}
```

**Phase to address:** Phase 4 (Launch Experience)

**Sources:**
- [Generic Shimmer Loading Skeletons](https://joshhomann.medium.com/generic-shimmer-loading-skeletons-in-swiftui-26fcd93ccee5)
- [SwiftUI .redacted Magic](https://naqeeb-ahmed.medium.com/swiftui-redacted-magic-achieve-shimmer-skeleton-loading-effect-with-just-one-line-of-code-5b203b540dad)

---

### Pitfall 10: Indeterminate Progress When Determinate is Possible

**What goes wrong:** Showing a spinner when you actually know the total count, frustrating users who can't gauge remaining time.

**Why it happens:** Laziness or not thinking about UX during implementation.

**Prevention:**
```swift
// BAD: Indeterminate when we know the count
ProgressView() // Spinner only

// GOOD: Determinate progress
ProgressView(value: Double(current), total: Double(total)) {
    Text("Processing \(current) of \(total)")
}
```

**Phase to address:** Phase 2 (Progress Indicators)

**Sources:**
- [Apple ProgressView Documentation](https://developer.apple.com/documentation/swiftui/progressview)
- [Mastering ProgressView in SwiftUI](https://swiftwithmajid.com/2021/11/25/mastering-progressview-in-swiftui/)

---

### Pitfall 11: Missing Cancellation UI

**What goes wrong:** Users cannot cancel long-running operations, leading to frustration when they want to abort.

**Why it happens:** Developers focus on the happy path and forget cancellation UX.

**Prevention:**
```swift
struct ProcessingView: View {
    var body: some View {
        VStack {
            ProgressView(value: progress)

            Button("Cancel") {
                viewModel.cancelProcessing()
            }
            .buttonStyle(.bordered)
        }
    }
}

// In ViewModel:
private var processingTask: Task<Void, Never>?

func cancelProcessing() {
    processingTask?.cancel()
    isProcessing = false
}
```

**Phase to address:** Phase 2 (Progress Indicators)

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Background Processing | @MainActor Task Inheritance (#1) | Use `nonisolated` functions for heavy work |
| Background Processing | Vision OCR on Main Thread (#2) | Run VNImageRequestHandler on background queue |
| Background Processing | Memory Blowout (#4) | Process images sequentially with autoreleasepool |
| Background Processing | Task Not Cancelled (#7) | Use `.task` modifier or manual cancellation |
| Progress Indicators | Animation Thrashing (#5) | Only animate UI state, not data changes |
| Progress Indicators | Too Frequent Updates (#6) | Throttle progress updates to ~10/sec |
| Progress Indicators | Indeterminate Progress (#10) | Use determinate progress when count is known |
| Progress Indicators | Missing Cancel UI (#11) | Always provide cancellation option |
| State Persistence | @AppStorage for Critical Data (#3) | Use SwiftData or file-based persistence |
| Launch Experience | Launch Screen Cache (#8) | Clear cache during development |
| Launch Experience | Skeleton Shape Mismatch (#9) | Match skeleton to actual content layout |

---

## ScreenSort-Specific Analysis

Based on the current codebase, these pitfalls are **actively present**:

1. **Pitfall #1 is the root cause of freezes.** `ProcessingViewModel` is `@MainActor @Observable` and `processNow()` runs heavy work synchronously.

2. **Pitfall #2 likely contributes.** OCR runs in the processing loop without explicit background queue dispatch.

3. **Pitfall #3 is partially present.** `@AppStorage("hasCompletedOnboarding")` is fine, but no persistence of processing results.

4. **Pitfall #7 is present.** `Task { await viewModel.processNow() }` in button action without cancellation handling.

5. **Pitfall #5 is mitigated.** Current code already has `animation(.spring(), value: viewModel.isProcessing)` scoped to UI state.

**Recommended fix order:**
1. Phase 1: Fix #1, #2, #4, #7 (eliminates freezes)
2. Phase 2: Address #6, #10, #11 (improves progress UX)
3. Phase 3: Implement proper persistence (#3)
4. Phase 4: Polish launch experience (#8, #9)

---

## Sources

### High Confidence (Official/Authoritative)
- [Apple: ProgressView Documentation](https://developer.apple.com/documentation/swiftui/progressview)
- [Apple: PHCachingImageManager Documentation](https://developer.apple.com/documentation/photos/phcachingimagemanager)
- [Apple: Preserving Your App's UI Across Launches](https://developer.apple.com/documentation/uikit/preserving-your-app-s-ui-across-launches)
- [Apple: VNRecognizeTextRequest Documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)

### Medium Confidence (Verified Community Sources)
- [Use Your Loaf: SwiftUI Tasks Blocking the MainActor](https://useyourloaf.com/blog/swiftui-tasks-blocking-the-mainactor/)
- [SwiftLee: @AppStorage Explained](https://www.avanderlee.com/swift/appstorage-explained/)
- [SwiftLee: Launch Screens in Xcode](https://www.avanderlee.com/xcode/launch-screen/)
- [Fatbobman: Mastering @AppStorage](https://fatbobman.com/en/posts/appstorage/)
- [Fatbobman: Mastering the SwiftUI task Modifier](https://fatbobman.com/en/posts/mastering_swiftui_task_modifier/)
- [Swift by Sundell: Memory Management with async/await](https://www.swiftbysundell.com/articles/memory-management-when-using-async-await/)
- [objc.io: The Photos Framework](https://www.objc.io/issues/21-camera-and-photos/the-photos-framework/)
- [Hacking with Swift: Why is Locking the UI Bad](https://www.hackingwithswift.com/read/9/2/why-is-locking-the-ui-bad)
