# Phase 3: State Persistence - Research

**Researched:** 2026-01-30
**Domain:** iOS State Persistence (UserDefaults, PhotoKit identifiers, cache management)
**Confidence:** HIGH

## Summary

This phase implements persistence for processed screenshot IDs and results, enabling the app to skip already-processed screenshots and restore results after termination. The research confirms that UserDefaults is the correct choice given the existing codebase patterns (already used for captions and corrections) and the relatively small data footprint (set of strings + array of result items).

The codebase already has established patterns in `CorrectionStore` and `PhotoLibraryService` that should be followed. `PHAsset.localIdentifier` is documented by Apple as "a unique string that persistently identifies the object" and is suitable for tracking processed screenshots. Cache invalidation can be handled by checking if assets still exist using `PHAsset.fetchAssets(withLocalIdentifiers:)`.

**Primary recommendation:** Create a `ProcessedScreenshotStore` singleton following the existing `CorrectionStore` pattern, storing processed IDs as a `Set<String>` (serialized to array) and results as a Codable array, with cache cleanup on app launch.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UserDefaults | iOS 2.0+ | Key-value persistence | Already used in codebase; appropriate for small datasets |
| Foundation (JSONEncoder/JSONDecoder) | iOS 8.0+ | Codable serialization | Standard Swift serialization |
| Photos (PHAsset) | iOS 8.0+ | Asset identification via localIdentifier | Already in use for photo operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @Observable | iOS 17+ | Reactive state for persisted data | If UI needs to react to store changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults | SwiftData/Core Data | Overkill for simple ID tracking; more complexity |
| UserDefaults | File storage | Similar performance; UserDefaults has better caching |
| Manual Codable | @AppStorage | @AppStorage doesn't work with @Observable; limited type support |

**No Installation Required:** All technologies are built into iOS.

## Architecture Patterns

### Recommended Project Structure
```
ScreenSort/
├── Services/
│   ├── ProcessedScreenshotStore.swift   # NEW: Persists processed IDs and results
│   └── CorrectionStore.swift            # EXISTING: Pattern to follow
├── ViewModels/
│   └── ProcessingViewModel.swift        # MODIFY: Integrate persistence
└── Models/
    └── ProcessingResultItem+Codable.swift  # MODIFY: Add Codable conformance
```

### Pattern 1: Singleton Store (Follow CorrectionStore Pattern)
**What:** A singleton service that encapsulates all persistence logic for processed screenshots
**When to use:** For app-wide state that needs to persist across launches
**Example:**
```swift
// Source: Existing CorrectionStore.swift pattern in codebase
final class ProcessedScreenshotStore: Sendable {

    private static let processedIDsKey = "ScreenSort.ProcessedIDs"
    private static let cachedResultsKey = "ScreenSort.CachedResults"

    static let shared = ProcessedScreenshotStore()
    private init() {}

    // MARK: - Processed IDs (Set<String> stored as Array)

    func markAsProcessed(_ assetId: String) {
        var ids = loadProcessedIDs()
        ids.insert(assetId)
        saveProcessedIDs(ids)
    }

    func isProcessed(_ assetId: String) -> Bool {
        loadProcessedIDs().contains(assetId)
    }

    func loadProcessedIDs() -> Set<String> {
        guard let array = UserDefaults.standard.stringArray(forKey: Self.processedIDsKey) else {
            return []
        }
        return Set(array)
    }

    private func saveProcessedIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: Self.processedIDsKey)
    }
}
```

### Pattern 2: Codable Results Persistence
**What:** Serialize ProcessingResultItem array to UserDefaults using JSONEncoder
**When to use:** When you need to persist structured data that survives app termination
**Example:**
```swift
// Source: https://www.hackingwithswift.com/example-code/system/how-to-load-and-save-a-struct-in-userdefaults-using-codable
func saveResults(_ results: [ProcessingResultItem]) {
    do {
        let data = try JSONEncoder().encode(results)
        UserDefaults.standard.set(data, forKey: Self.cachedResultsKey)
    } catch {
        print("[ProcessedScreenshotStore] Failed to encode results: \(error)")
    }
}

func loadResults() -> [ProcessingResultItem] {
    guard let data = UserDefaults.standard.data(forKey: Self.cachedResultsKey) else {
        return []
    }
    do {
        return try JSONDecoder().decode([ProcessingResultItem].self, from: data)
    } catch {
        print("[ProcessedScreenshotStore] Failed to decode results: \(error)")
        return []
    }
}
```

### Pattern 3: Cache Invalidation on App Launch
**What:** Clean up stale entries for deleted photos when app launches
**When to use:** Requirement PERSIST-04 - Cache invalidation when source screenshots deleted
**Example:**
```swift
// Source: https://developer.apple.com/documentation/photokit/phasset/1624732-fetchassets
func cleanupDeletedAssets() {
    let processedIDs = loadProcessedIDs()
    guard !processedIDs.isEmpty else { return }

    // Fetch all stored IDs to check if they still exist
    let fetchResult = PHAsset.fetchAssets(
        withLocalIdentifiers: Array(processedIDs),
        options: nil
    )

    // Build set of IDs that still exist
    var existingIDs = Set<String>()
    fetchResult.enumerateObjects { asset, _, _ in
        existingIDs.insert(asset.localIdentifier)
    }

    // Remove IDs that no longer exist
    let staleIDs = processedIDs.subtracting(existingIDs)
    if !staleIDs.isEmpty {
        saveProcessedIDs(existingIDs)

        // Also clean up cached results
        var results = loadResults()
        results.removeAll { staleIDs.contains($0.assetId) }
        saveResults(results)

        print("[ProcessedScreenshotStore] Cleaned up \(staleIDs.count) stale entries")
    }
}
```

### Anti-Patterns to Avoid
- **Storing full PHAsset objects:** PHAsset is not Codable; store localIdentifier strings only
- **Loading entire dataset on every check:** Load once at startup, use in-memory Set for lookups
- **Forgetting Sendable:** Store must be Sendable for safe access from async contexts
- **Using @AppStorage with @Observable:** These don't work together; use manual UserDefaults access

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ID uniqueness | Custom deduplication | Set<String> | Built-in, O(1) lookup |
| JSON serialization | Manual string building | JSONEncoder/JSONDecoder | Type-safe, handles edge cases |
| Checking asset existence | Manual fetch loops | PHAsset.fetchAssets(withLocalIdentifiers:) | Single API call for batch check |
| Thread-safe storage | Manual locking | Singleton + Sendable | Swift concurrency handles it |

**Key insight:** UserDefaults handles its own caching, so accessing it in normal operations is efficient. Don't add a caching layer on top.

## Common Pitfalls

### Pitfall 1: Set<String> Cannot Be Stored Directly in UserDefaults
**What goes wrong:** Attempting `UserDefaults.standard.set(mySet, forKey:)` fails silently or crashes
**Why it happens:** UserDefaults only supports: String, Number, Date, Data, Array, Dictionary
**How to avoid:** Convert Set to Array before storing: `Array(mySet)`, convert back on load: `Set(array)`
**Warning signs:** Data not persisting between launches; nil values on retrieval

### Pitfall 2: ProcessingResultItem Needs Codable Conformance
**What goes wrong:** Compiler error when trying to encode/decode
**Why it happens:** The existing ProcessingResultItem struct doesn't conform to Codable
**How to avoid:** Add Codable conformance to ProcessingResultItem and its nested Status enum
**Warning signs:** "Type does not conform to protocol 'Encodable'"

### Pitfall 3: UUID in ProcessingResultItem Won't Round-Trip
**What goes wrong:** Decoded items have different UUIDs than when saved
**Why it happens:** `let id = UUID()` generates new ID on every decode
**How to avoid:** Either include UUID in Codable encoding, or use assetId as the stable identifier for equality
**Warning signs:** Duplicate items appearing in results list

### Pitfall 4: Forgetting to Update Processed IDs After Each Screenshot
**What goes wrong:** App crash/termination loses progress; screenshots get reprocessed
**Why it happens:** Waiting until batch completion to persist
**How to avoid:** Call `markAsProcessed()` immediately after each screenshot succeeds
**Warning signs:** Reprocessing screenshots that were already done

### Pitfall 5: Not Cleaning Up Deleted Photo IDs
**What goes wrong:** Processed IDs set grows unbounded; includes references to deleted photos
**Why it happens:** Users delete screenshots but app keeps stale IDs
**How to avoid:** Run cleanup on app launch using PHAsset.fetchAssets(withLocalIdentifiers:)
**Warning signs:** Growing UserDefaults size over time; phantom entries

### Pitfall 6: localIdentifier Instability Edge Cases
**What goes wrong:** Some processed screenshots get reprocessed after device migration
**Why it happens:** localIdentifier can change during Quick Start device transfer or major iOS updates
**How to avoid:** Accept this as rare edge case; worst case is re-processing (not data loss)
**Warning signs:** Users report duplicates after switching devices

## Code Examples

Verified patterns from official sources:

### Making ProcessingResultItem Codable
```swift
// Source: Existing pattern in codebase (Correction.swift already does this)
struct ProcessingResultItem: Identifiable, Codable, Sendable {
    let id: UUID
    let assetId: String
    let status: Status
    let contentType: ScreenshotType
    let title: String?
    let creator: String?
    let message: String
    let serviceLink: String?

    enum Status: String, Codable, Sendable {
        case success
        case flagged
        case failed
    }

    // Custom initializer to generate UUID
    init(
        assetId: String,
        status: Status,
        contentType: ScreenshotType,
        title: String?,
        creator: String?,
        message: String,
        serviceLink: String?
    ) {
        self.id = UUID()
        self.assetId = assetId
        self.status = status
        self.contentType = contentType
        self.title = title
        self.creator = creator
        self.message = message
        self.serviceLink = serviceLink
    }
}
```

### Filtering Unprocessed Screenshots
```swift
// Source: ProcessingViewModel.swift pattern, modified for persistence
func processNow() async {
    // ... existing setup ...

    let allScreenshots = try await photoService.fetchScreenshots()
    let processedIDs = ProcessedScreenshotStore.shared.loadProcessedIDs()

    // Filter out already-processed screenshots
    let screenshots = allScreenshots.filter { asset in
        !processedIDs.contains(asset.localIdentifier)
    }

    // Process and mark as complete
    for asset in screenshots {
        let result = await processScreenshot(asset: asset, playlistId: playlistId)
        results.append(result)

        // Mark as processed immediately (survives crash)
        ProcessedScreenshotStore.shared.markAsProcessed(asset.localIdentifier)
    }

    // Save results for display on next launch
    ProcessedScreenshotStore.shared.saveResults(results)
}
```

### Loading Cached Results on App Launch
```swift
// Source: Standard SwiftUI onAppear pattern
func checkInitialState() {
    photoPermissionStatus = photoService.authorizationStatus()
    isYouTubeAuthenticated = authService.isAuthenticated
    googleDocURL = googleDocsService.documentURL

    // Load cached results from previous session
    let cachedResults = ProcessedScreenshotStore.shared.loadResults()
    if !cachedResults.isEmpty {
        self.results = cachedResults
    }

    // Clean up any stale entries for deleted photos
    Task {
        ProcessedScreenshotStore.shared.cleanupDeletedAssets()
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ObservableObject + @AppStorage | @Observable + manual UserDefaults | iOS 17 (2023) | @AppStorage doesn't work with @Observable |
| NSCoding/NSKeyedArchiver | Codable + JSONEncoder | Swift 4 (2017) | Much simpler, type-safe |
| PHAsset serialization | Store localIdentifier only | Always | PHAsset not persistable |

**Deprecated/outdated:**
- @Published with UserDefaults: Replaced by @Observable pattern
- NSUserDefaults (Objective-C): Use UserDefaults (Swift)

## Open Questions

Things that couldn't be fully resolved:

1. **PHCloudIdentifier for cross-device persistence**
   - What we know: localIdentifier may change during device migration via Quick Start
   - What's unclear: Whether PHCloudIdentifier would be more stable
   - Recommendation: Accept localIdentifier instability as rare edge case; re-processing is safe

2. **UserDefaults size limits**
   - What we know: Apple recommends < 100KB; large data slows backup/restore
   - What's unclear: Exact breaking point
   - Recommendation: Monitor; if > 1000 screenshots processed, consider file-based storage

3. **Concurrent access during background processing**
   - What we know: UserDefaults is thread-safe; Sendable requirement handles Swift concurrency
   - What's unclear: Whether iOS 18+ background modes affect this
   - Recommendation: Current Sendable singleton pattern is correct

## Sources

### Primary (HIGH confidence)
- Existing codebase: `CorrectionStore.swift` - Established UserDefaults + Codable pattern
- Existing codebase: `PhotoLibraryService.swift` - Caption storage and PHAsset patterns
- [Hacking with Swift - UserDefaults basics](https://www.hackingwithswift.com/read/12/2/reading-and-writing-basics-userdefaults) - UserDefaults supported types
- [Hacking with Swift - Codable + UserDefaults](https://www.hackingwithswift.com/example-code/system/how-to-load-and-save-a-struct-in-userdefaults-using-codable) - JSONEncoder pattern

### Secondary (MEDIUM confidence)
- [SwiftLee - User Defaults reading and writing](https://www.avanderlee.com/swift/user-defaults-preferences/) - Best practices
- [Fatbobman - UserDefaults and Observation](https://fatbobman.com/en/posts/userdefaults-and-observation/) - @Observable limitations
- [Sarunw - Codable enums](https://sarunw.com/posts/codable-synthesis-for-enums-with-associated-values-in-swift/) - Enum serialization
- [Medium - Observing photo changes](https://medium.com/@macka/observing-photo-album-changes-ios-swift-23a4c2e741ff) - PHChange patterns

### Tertiary (LOW confidence)
- Apple Developer Forums: localIdentifier stability concerns during device migration
- Community reports of localIdentifier changing after iOS updates (unverified frequency)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing codebase patterns
- Architecture: HIGH - Follows established CorrectionStore singleton pattern
- Pitfalls: HIGH - Well-documented UserDefaults and Codable gotchas

**Research date:** 2026-01-30
**Valid until:** 60 days (stable iOS APIs, no major changes expected)
