# Codebase Concerns

**Analysis Date:** 2026-01-30

## Tech Debt

**Undocumented Photo Library API for Captions:**
- Issue: Photo caption storage uses undocumented Photos framework APIs, which may not work reliably across iOS versions
- Files: `ScreenSort/Services/PhotoLibraryService.swift` (lines 134-155), `ScreenSort/Services/OCRService.swift`
- Impact: Caption reading/writing can fail silently; captions may not persist reliably between app launches; Apple could break this API in future iOS updates
- Fix approach: Migrate to SwiftData or Core Data for metadata storage instead of relying on photo captions. Create a proper metadata model keyed by PHAsset.localIdentifier

**UserDefaults as Primary Data Store:**
- Issue: Corrections and captions are persisted via UserDefaults, which is not optimized for structured data or large datasets
- Files: `ScreenSort/Services/CorrectionStore.swift` (lines 69-90), `ScreenSort/Services/PhotoLibraryService.swift` (lines 149-154)
- Impact: Storage is inefficient; full data reload required on every access; no indexing or query capabilities; data could grow unbounded
- Fix approach: Migrate to SwiftData for persistent storage with proper schema, versioning, and migration support. Implement pagination for large correction lists.

**Force Unwrapping in URLComponents:**
- Issue: Force unwraps URLComponents initialization which could crash if URL string is malformed
- Files: `ScreenSort/Services/GoogleDocsService.swift` (line 147), `ScreenSort/Services/GoogleDocsService.swift` (line 172)
- Impact: App crash if URL string construction fails; no graceful error handling
- Fix approach: Use guard let with proper error throwing instead of force unwrap (e.g., `guard let components = URLComponents(string: url) else { throw ... }`)

**Hardcoded API Endpoints:**
- Issue: API endpoint URLs are hardcoded throughout service files as strings
- Files: Multiple service files (GoogleDocsService.swift, YouTubeService.swift, TMDbService.swift)
- Impact: Difficult to test; breaks if API endpoints change; no environment-specific configuration
- Fix approach: Create an APIConfiguration struct with environment-specific endpoints; centralize all endpoints in one location

## Known Bugs

**OCR Snapshot Memory Accumulation:**
- Symptoms: ocrSnapshots dictionary in ProcessingViewModel grows unbounded during batch processing
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 22-24, 174, 251-252)
- Trigger: Process large number of screenshots (100+) in one session
- Workaround: None currently; user must force quit and restart app
- Fix approach: Implement configurable retention policy - keep only recent snapshots or add manual cleanup option

**Google Docs Deduplication Cache Not Persisted:**
- Symptoms: Duplicate entries may be logged if app crashes or restarts before processing completes
- Files: `ScreenSort/Services/GoogleDocsService.swift` (lines 70, 94-97)
- Trigger: App crash or force quit during active processing
- Workaround: User can manually delete duplicate entries from Google Doc
- Fix approach: Persist entriesCache to disk after each successful log operation; consider remote deduplication

**Caption Update Failures are Silent:**
- Symptoms: Photo captions fail to update but no error is surfaced to user; only logged to console
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 305-306, 352-353, 396-397, 421)
- Trigger: Photo library permission changes or undocumented API failure
- Workaround: Check photo captions manually in Photos app
- Fix approach: Propagate caption errors to result message; show warnings in UI when captions cannot be updated

## Security Considerations

**OAuth Token Storage and Refresh:**
- Risk: Refresh tokens stored in Keychain; if device is compromised, tokens could be used to access user's Google account
- Files: `ScreenSort/Services/KeychainService.swift` (entire file), `ScreenSort/Services/AuthService.swift`
- Current mitigation: Keychain access requires device unlock; tokens marked as `kSecAttrAccessibleWhenUnlocked`
- Recommendations:
  1. Implement token rotation on each refresh
  2. Add expiry to refresh tokens (currently unlimited)
  3. Store tokens using `kSecAttrAccessibleAfterFirstUnlock` for better UX without sacrificing security much
  4. Clear tokens on app uninstall (iOS handles this automatically but document it)

**Client ID Hardcoding:**
- Risk: YouTube OAuth client ID is loaded from bundle and visible in compiled binary
- Files: `ScreenSort/Services/AuthService.swift` (line 18)
- Current mitigation: Uses PKCE flow which protects against token theft; client ID alone cannot create tokens
- Recommendations: This is acceptable for iOS apps, but document why client secret is NOT stored (it would be insecure)

**Undocumented API Reliance:**
- Risk: Using undocumented photo caption APIs that may break without warning
- Files: `ScreenSort/Services/PhotoLibraryService.swift` (lines 134-155)
- Current mitigation: Errors are caught and logged, but caption failures are silently ignored
- Recommendations: Replace with documented SwiftData approach; add unit tests for metadata persistence

**No Rate Limiting on API Calls:**
- Risk: Rapid API calls could trigger quota limits or IP bans
- Files: All service files making API requests (YouTubeService, TMDbService, GoogleBooksService)
- Current mitigation: Processing is sequential (not parallel), naturally rate-limited by device performance
- Recommendations: Add exponential backoff retry logic; track API quota usage; implement circuit breaker pattern

## Performance Bottlenecks

**Sequential Screenshot Processing:**
- Problem: Screenshots processed one at a time in a loop; 100 screenshots take proportionally longer
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 224-231)
- Cause: sync await in sequential for loop; no parallelism despite TaskGroup usage elsewhere
- Improvement path: Use TaskGroup to process screenshots in parallel (batch size of 3-5 to avoid API quota issues); implement progress tracking per group

**OCR Performance on Large Batches:**
- Problem: Full-resolution image OCR is CPU-intensive; 30+ screenshots in one batch causes UI lag
- Files: `ScreenSort/Services/OCRService.swift`, `ScreenSort/ViewModels/ProcessingViewModel.swift` (line 248)
- Cause: OCR processes full-resolution images; no image downscaling
- Improvement path: Downscale screenshots before OCR (max 1024px width); implement OCR in background thread; cache OCR results

**Synchronous JSON Encoding/Decoding:**
- Problem: Large corrections dictionary being encoded/decoded on main thread
- Files: `ScreenSort/Services/CorrectionStore.swift` (lines 75, 85)
- Cause: JSONEncoder/Decoder runs synchronously in saveCorrectionsDict/loadAllCorrectionsDict
- Improvement path: Move encoding to background queue; implement lazy loading of corrections; consider streaming approach

**Photo Album Creation Parallelization:**
- Problem: All album creation happens in TaskGroup but still waits sequentially
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 212-220)
- Cause: Albums are created before processing begins, blocking start of processing
- Improvement path: Create albums lazily as needed; implement concurrent album creation with proper error recovery

## Fragile Areas

**Error Handling in processScreenshot:**
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 245-274)
- Why fragile:
  - OCR errors caught generically; specific OCR failures (no text found) treated same as VisionKit failures
  - Classification errors not explicitly handled; assumes classifier never throws
  - Any error in extraction cascade results in .flagged status with error message
- Safe modification: Add specific catch blocks for each error type; test with OCR-impossible images
- Test coverage: No unit tests for error cascade paths

**AI Classification Fallback Logic:**
- Files: `ScreenSort/Services/ScreenshotClassifier.swift`, `ScreenSort/Services/AIScreenshotClassifier.swift`
- Why fragile:
  - Fallback between AI and keyword classifier not formally defined
  - No version checking for iOS 18.1+ features
  - Confidence threshold (0.6) hardcoded in AIClassificationConfig; no way to tune per-category
- Safe modification: Add comprehensive integration tests between both classifiers; mock Foundation Models
- Test coverage: Only basic API verification tests exist; no logic tests

**Google Docs Rate Limiting:**
- Files: `ScreenSort/Services/GoogleDocsService.swift` (lines 102-114, 123-141)
- Why fragile:
  - No handling for 429 (too many requests) responses
  - No backoff between batch updates
  - entriesCache is in-memory only; lost on app restart
- Safe modification: Add retry logic with exponential backoff; implement persistent deduplication
- Test coverage: No tests for rate limit scenarios

**Photo Library Permission State Transitions:**
- Files: `ScreenSort/ViewModels/ProcessingViewModel.swift` (lines 137-140, 173-176), `ScreenSort/Views/ProcessingView.swift` (lines 106-188)
- Why fragile:
  - Permission denied state doesn't allow request again without restarting app
  - Limited photo access mode (iOS 17+) not fully tested
  - No observer for permission changes during app use
- Safe modification: Add PHPhotoLibraryChangeObserver for permission state changes; implement re-request UI
- Test coverage: No tests for permission state transitions

**Meme Detection Placeholder:**
- Files: `ScreenSort/Services/MemeDetector.swift`
- Why fragile: Meme detection is a stub that always returns false; any screenshots without clear text get flagged
- Safe modification: Implement actual meme detection using Vision/ML; add test cases
- Test coverage: No tests; actual implementation missing

## Scaling Limits

**In-Memory Result Accumulation:**
- Current capacity: 500-1000 ProcessingResultItem objects before memory pressure
- Limit: Processing 1000+ screenshots in one session causes memory warnings
- Scaling path: Implement pagination in results display; stream results to Google Docs incrementally; clear old results from memory

**UserDefaults Storage Limit:**
- Current capacity: ~5MB per app container (varies by device)
- Limit: CorrectionStore will fail to encode when corrections exceed ~2MB
- Scaling path: Migrate to Core Data with proper growth limits; archive old corrections; implement retention policy

**Google Docs API Document Size:**
- Current capacity: Documents up to 1MB can be modified (API limit)
- Limit: Logging 10,000+ items (at 100 bytes each) approaches 1MB
- Scaling path: Implement document rotation (create new doc yearly); implement archive document feature; batch updates

**Photo Library Album Limit:**
- Current capacity: No hard limit, but iOS PhotoKit performs poorly with 100K+ items
- Limit: Albums with 5000+ photos show UI lag in Photos app
- Scaling path: Implement filtering by date ranges; consider custom gallery instead of native albums

## Test Coverage Gaps

**No Unit Tests for Service Layer:**
- What's not tested:
  - MusicExtractor parsing logic
  - MovieExtractor parsing logic
  - BookExtractor parsing logic
  - Error handling in extractors
  - API response parsing and error cases
- Files: All files in `ScreenSort/Services/`
- Risk: Breaking changes not caught; extractors could regress; error paths untested
- Priority: High - extractors are core business logic

**No Integration Tests Between Services:**
- What's not tested:
  - Full processing pipeline (OCR → classify → extract → log)
  - Service dependency chains
  - Error recovery and retries
  - Permission state transitions during processing
- Files: ProcessingViewModel (orchestrator)
- Risk: Pipeline failures only caught in production; hard to reproduce
- Priority: High - this is the critical path

**No Tests for UI State Management:**
- What's not tested:
  - ProcessingViewModel state transitions
  - CorrectionReviewViewModel filtering and corrections
  - Permission state changes during UI interaction
- Files: `ScreenSort/ViewModels/`
- Risk: UI state inconsistencies; race conditions on main actor
- Priority: Medium - found during manual testing but should be automated

**No Mock Implementations for External Services:**
- What's not tested:
  - YouTube search and playlist operations
  - TMDb search
  - Google Books search
  - Google Docs API operations
  - OAuth token refresh
- Files: All service files with protocol definitions
- Risk: Tests cannot run without real API credentials; API rate limits hit during testing
- Priority: High - prevents effective testing

**No Negative Test Cases:**
- What's not tested:
  - Invalid OCR results (empty text, corrupted images)
  - API failures (404, 500, timeout)
  - Network errors during requests
  - Permission denials mid-processing
  - Keychain failures
- Files: All service files
- Risk: Unknown failure modes; crash when unexpected states occur
- Priority: High

## Missing Critical Features

**No Undo/Redo for Corrections:**
- Problem: Once a correction is applied, it's permanent. No history of what was changed.
- Blocks: Users cannot experiment with corrections; accidental corrections are hard to fix
- Difficulty: Low - CorrectionStore already has apply/revert; just need UI

**No Batch Operations:**
- Problem: Users can only correct one screenshot at a time
- Blocks: Correcting 50 misclassified items requires 50 taps
- Difficulty: Medium - requires UI refactor and batch processing logic

**No Search/Filter by Content:**
- Problem: Can't search for "Taylor Swift" songs or "Netflix" movies in results
- Blocks: Finding specific items in large result sets
- Difficulty: Medium - requires indexing and search UI

**No Metadata Export:**
- Problem: Results are logged to Google Doc but not exportable in other formats (CSV, JSON)
- Blocks: Integration with other tools; data analysis
- Difficulty: Low - add export options to results view

**No Custom Classification Rules:**
- Problem: Classification thresholds and rules are hardcoded; can't tune for user preferences
- Blocks: Users with specific workflows can't adapt app behavior
- Difficulty: Medium - requires settings screen and rule engine

**No Offline Mode:**
- Problem: App requires network connection for YouTube, TMDb, Google Books APIs
- Blocks: Users can't process screenshots on airplane mode
- Difficulty: High - requires caching API results and offline extraction

## Dependencies at Risk

**Foundation Models (Apple Intelligence):**
- Risk: Framework only available on iPhone 15 Pro+ with iOS 18.1+; no backward compatibility
- Impact: Feature completely unavailable on older devices; keyboard fallback is keyword-based and less accurate
- Migration plan: Keyword-based classifier is already fallback; document iOS 17 compatibility (limited AI features)

**Google OAuth Complexity:**
- Risk: Google frequently updates OAuth flows and requirements; PKCE implementation must stay current
- Impact: Authentication could break; users unable to sign in
- Migration plan: Migrate to Google Sign-In SDK when available; add oauth2 library instead of manual implementation

**URLSession No Resource Constraint:**
- Risk: URLSession.shared used without configuration; no timeout, memory limit, or concurrent request limits
- Impact: Long-running requests can hang; memory exhaustion on many concurrent requests
- Migration plan: Create custom URLSessionConfiguration with timeouts, memory limits, and request limits

**Photos Framework Limitations:**
- Risk: Apple restricts photo access in iOS 14+; limited access mode increasingly common
- Impact: App may only see subset of screenshots in photo library
- Migration plan: No workaround; document limitation in help text; implement request limited access button

## Performance Degradation Scenarios

**Processing with Limited Photo Access:**
- Scenario: User grants limited photo access (iOS 17+); app only sees subset of photos
- Current behavior: App processes only visible photos; silently skips others
- Risk: User thinks all screenshots processed but many are missed
- Fix: Add prominent warning when limited access detected; implement request full access flow

**Large Photo Library (10K+ screenshots):**
- Scenario: User with many screenshots tries to process all at once
- Current behavior: Fetch takes several seconds; memory spikes during batch processing
- Risk: App becomes unresponsive; crashes on older devices
- Fix: Implement pagination; show progress; allow cancellation

**Poor Network Conditions:**
- Scenario: User on slow/spotty network tries to add songs to YouTube playlist
- Current behavior: Requests timeout after default URLSession timeout
- Risk: Users see "failed" status with no recourse
- Fix: Add retry UI; implement exponential backoff; show network status indicator

---

*Concerns audit: 2026-01-30*
