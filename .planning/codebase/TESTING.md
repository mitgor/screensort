# Testing Patterns

**Analysis Date:** 2026-01-30

## Test Framework

**Runner:**
- XCTest (built-in Apple framework)
- Async/await support for testing asynchronous code
- Config: Project configured in `ScreenSort.xcodeproj`

**Run Commands:**
```bash
xcodebuild test -scheme ScreenSort                    # Run all tests
xcodebuild test -scheme ScreenSort -enableCodeCoverage YES  # Run with coverage
```

**Assertion Library:**
- Native XCTest assertions: `XCTAssertEqual()`, `XCTAssertNotNil()`, `XCTAssertFalse()`, `XCTFail()`

## Test File Organization

**Location:**
- Test files in `ScreenSortTests/` directory
- Test files separated from source code (not co-located)

**Naming:**
- Class names suffixed with `Tests`: `APIVerificationTests`
- File names match test class: `APIVerificationTests.swift`

**Current Structure:**
```
ScreenSortTests/
└── APIVerificationTests.swift    # API integration tests
```

## Test Structure

**Test Class Organization:**

```swift
final class APIVerificationTests: XCTestCase {
    // MARK: - YouTube Data API v3

    func testYouTubeAPIAccess() async throws {
        // Test implementation
    }

    // MARK: - TMDb API

    func testTMDbAPIAccess() async throws {
        // Test implementation
    }
}
```

**Patterns:**
- Test classes inherit from `XCTestCase`
- Test methods prefixed with `test` and named descriptively: `testYouTubeAPIAccess()`
- Tests marked `async throws` for asynchronous operations
- MARK comments separate test groups by feature area

**Setup/Teardown:**
- Limited use in current codebase
- Tests are designed to be independent (no shared state)
- Each test verifies API configuration and access directly

## Test Types

**Integration Tests (API Verification):**
- Location: `ScreenSortTests/APIVerificationTests.swift`
- Purpose: Verify external API connectivity and credentials
- Pattern: Direct API calls with configuration verification

Example from `APIVerificationTests.swift`:
```swift
func testYouTubeAPIAccess() async throws {
    // Verify API key is configured
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
          !apiKey.isEmpty,
          apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
        XCTFail("YOUTUBE_API_KEY not configured in Secrets.xcconfig")
        return
    }

    // Use actual API to verify connectivity
    let videoId = "dQw4w9WgXcQ"
    let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoId)&key=\(apiKey)"
    let url = URL(string: urlString)!

    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = response as! HTTPURLResponse

    // Verify success and response structure
    XCTAssertEqual(httpResponse.statusCode, 200, "YouTube API returned \(httpResponse.statusCode)")

    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let items = json["items"] as? [[String: Any]]
    XCTAssertNotNil(items, "Response missing 'items' array")
    XCTAssertFalse(items!.isEmpty, "No video found for ID \(videoId)")

    print("YouTube API: SUCCESS - Quota cost: 1 unit (videos.list)")
}
```

**Unit Tests:**
- Not detected in current codebase
- Recommendation: Add unit tests for extraction logic and classification

**E2E Tests:**
- Not implemented in current codebase
- Manual testing via UI used for full workflows

## Async Testing Pattern

**Async/Await Pattern:**
```swift
func testYouTubeAPIAccess() async throws {
    // Async operations directly in test
    let (data, response) = try await URLSession.shared.data(from: url)
    // Assertions follow
}
```

**Pattern:**
- Test methods marked `async throws`
- Call async functions directly with `await`
- Use `try` for throwing operations
- Assertions execute after async completion

## Mocking

**Strategy:**
- Not required for API integration tests (direct API calls)
- Protocols used in production code enable mocking when needed

**Mockable Interfaces:**
- `ScreenshotClassifierProtocol` - enables testing without AI
- `PhotoLibraryServiceProtocol` - enables testing without Photos framework
- `OCRServiceProtocol` - enables testing without Vision framework

Example from `ProcessingViewModel.swift`:
```swift
init(
    photoService: PhotoLibraryServiceProtocol,
    ocrService: OCRServiceProtocol,
    classifier: ScreenshotClassifierProtocol,
    musicExtractor: MusicExtractorProtocol,
    // ... other protocols
) {
    self.photoService = photoService
    self.ocrService = ocrService
    // ... store others
}
```

**Recommendation for Unit Tests:**
- Create mock implementations of protocols (currently commented out in code)
- Mock `PhotoLibraryServiceProtocol` to avoid Photos framework dependency
- Mock `OCRServiceProtocol` with fixed text observations
- Mock API services to test error handling paths

## Test Coverage

**Current Status:**
- 1 test file with 3 integration tests
- Coverage: APIs only
- No unit test coverage for business logic

**Target Coverage:**
```
Areas to test:
- Screenshot classification (ScreenshotClassifier)
- Metadata extraction (MusicExtractor, MovieExtractor, BookExtractor)
- Error handling and recovery paths
- ViewModel state transitions
```

**View Coverage:**
```bash
# Generate coverage report:
xcodebuild test -scheme ScreenSort -enableCodeCoverage YES
open derived_data_path/Build/ProfileData/.../
```

## Configuration and Secrets

**Test Configuration:**
- Tests verify API credentials are present in `Config/Secrets.xcconfig`
- Configuration loaded via `Bundle.main.object(forInfoDictionaryKey:)`
- Tests fail fast if required keys are missing or have placeholder values

Example:
```swift
guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
      !apiKey.isEmpty,
      apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
    XCTFail("YOUTUBE_API_KEY not configured in Secrets.xcconfig")
    return
}
```

## Common Patterns and Best Practices

**Error Assertions:**
```swift
// Testing throwing functions
XCTAssertThrowsError(try someThrowingFunction())

// Testing async throwing
let error = try? await someAsyncThrowingFunction()
XCTAssertNotNil(error)
```

**Response Parsing:**
```swift
// Parse JSON responses
let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let items = json["items"] as? [[String: Any]]

// Verify structure
XCTAssertNotNil(items, "Response missing 'items' array")
```

**HTTP Response Verification:**
```swift
let (data, response) = try await URLSession.shared.data(from: url)
let httpResponse = response as! HTTPURLResponse
XCTAssertEqual(httpResponse.statusCode, 200)
```

## Test Execution Tips

**Run Specific Test:**
```bash
xcodebuild test -scheme ScreenSort -testLanguage swift -testPlan ScreenSortTests -testNameMatches "*YouTube*"
```

**Parallel Execution:**
- XCTest runs tests in parallel by default
- Tests must be independent (no shared state)
- Each test should clean up after itself

## Missing Tests

**Recommended Additions:**

1. **Classification Tests** (`ScreenshotClassifier`):
   - Test music keyword detection
   - Test movie keyword detection
   - Test confidence scoring
   - Test edge cases (empty text, mixed content)

2. **Extraction Error Tests**:
   - Test handling of low-confidence extractions
   - Test missing required fields
   - Test AI model unavailability fallback

3. **ViewModel Tests**:
   - Test state transitions during processing
   - Test error recovery paths
   - Test result aggregation

4. **Service Tests**:
   - Mock API responses for various scenarios
   - Test network error handling
   - Test cache behavior in APIClient

5. **UI Tests** (using XCUITest):
   - Test permission prompts
   - Test photo processing workflow
   - Test error display

---

*Testing analysis: 2026-01-30*
