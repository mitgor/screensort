# Coding Conventions

**Analysis Date:** 2026-01-30

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `ScreenshotClassifier.swift`, `ProcessingViewModel.swift`
- Descriptors in filename match class/struct name
- Service files suffixed with service type: `APIClient.swift`, `OCRService.swift`, `GoogleDocsService.swift`
- Component files in `Views/Components/`: `AsyncThumbnailView.swift`, `ReviewCard.swift`
- Model files in `Models/` directory with descriptive names: `MovieMetadata.swift`, `Errors.swift`

**Functions:**
- camelCase with verb-noun pattern: `processScreenshot()`, `extractMusicMetadata()`, `classifyWithAI()`
- Async functions use `async` keyword and suffix for clarity: `classifyWithAI() async`, `recognizeText() async throws`
- Private helper functions use descriptive camelCase: `combineObservationsToLowercase()`, `countKeywordMatches()`
- Computed properties use noun format without parentheses: `isValid`, `isHighConfidence`, `displayTitle`

**Variables:**
- Local variables: camelCase starting with lowercase: `photoPermissionStatus`, `isProcessing`, `textObservations`
- State variables: `@State private var` with camelCase: `var photoPermissionStatus = .notDetermined`
- Private stored properties: camelCase prefixed with function intent: `musicExtractor`, `googleDocsService`
- Constants: PascalCase for configuration enums, lowercase for specific values: `ClassificationConfig.minimumMatchThreshold`, `AppTheme.spacingLG`

**Types:**
- PascalCase for all types: `struct Screenshot`, `enum ScreenshotType`, `class ScreenshotClassifier`
- Protocol names use suffix or descriptive phrase: `ScreenshotClassifierProtocol`, `PhotoLibraryServiceProtocol`
- Associated types and generics maintain PascalCase: `ProcessingResultItem`, `TextObservation`
- Error enums follow pattern: `enum PhotoLibraryError`, `enum YouTubeError`, `enum MusicExtractionError`

## Code Style

**Formatting:**
- 4-space indentation (Swift standard)
- Line length: target under 120 characters
- Blank lines between logical sections
- Spacing: 1 blank line between methods, properties grouped logically

**Structure and Organization:**
- MARK comments divide code into logical sections: `// MARK: - Public API`, `// MARK: - Dependencies`, `// MARK: - Private Helpers`
- Related properties and methods grouped together
- Public API first, then private helpers
- Dependencies declared at top of class/struct after MARK

**Import Organization:**
```swift
import Foundation
import SwiftUI
import Photos
import UIKit
import Observation
import FoundationModels
```

Order:
1. System frameworks (Foundation, SwiftUI, UIKit)
2. Platform frameworks (Photos, Observation, FoundationModels)
3. No blank line between groups

**Access Modifiers:**
- Explicit `private` for properties and methods (e.g., `private let cache: URLCache`)
- Use `final` for classes that won't be subclassed: `final class ScreenshotClassifier`
- Use `@MainActor` for UI-bound ViewModels: `@MainActor final class ProcessingViewModel`

## Error Handling

**Error Protocol:**
- Domain-specific error enums conform to `Error` and `RecoverableError`
- Implement `errorDescription` with user-friendly message
- Implement `recoverySuggestion` with actionable guidance
- Implement `isRetryable` boolean to indicate if operation can be retried

Example from `Errors.swift`:
```swift
enum PhotoLibraryError: Error, RecoverableError {
    case accessDenied
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access was denied."
        case .assetNotFound:
            return "The photo could not be found."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Open Settings > Privacy > Photos and grant ScreenSort access."
        case .assetNotFound:
            return "The photo may have been deleted. Refresh and try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .accessDenied, .assetNotFound:
            return false
        }
    }
}
```

**Error Throwing:**
- Use `throws` keyword for functions that can fail
- Use `async throws` for async operations
- Throw specific domain errors, not generic Error
- Catch errors at appropriate layer with `do/catch`
- Store last error in ViewModel for UI display: `var lastError: String?`

## Logging

**Framework:** Console logging via `print()` with prefixes

**Patterns:**
- Use emoji prefixes for log types:
  - `📸` for photo/screenshot operations
  - `🎵` for music operations
  - `🎬` for movie operations
  - `📚` for book operations
  - `🔄` for processing steps
  - `✅` for successes
  - `🏁` for completion

- Include context in brackets: `print("📸 [ProcessingViewModel] Processing \(index + 1)/\(screenshots.count)")`
- Log at key decision points and error boundaries
- Include relevant data values in log output

Example:
```swift
print("📸 [ProcessingViewModel] Fetching screenshots...")
print("📸 [ProcessingViewModel] Found \(allScreenshots.count) total screenshots")
```

## Comments

**Documentation Comments:**
- Use `///` for public API documentation
- Include usage examples for complex functions
- Document parameters with `- Parameter name: description`
- Document return values with `- Returns: description`

Example from `ScreenshotClassifier.swift`:
```swift
/// Classify a screenshot using AI when available, with keyword fallback.
///
/// This method uses Apple Intelligence for semantic classification when available
/// on supported devices (iPhone 15 Pro+, iOS 18.1+). Falls back to keyword-based
/// classification on older devices or when AI is unavailable.
///
/// - Parameter textObservations: Array of text detected in the screenshot.
/// - Returns: The detected screenshot type.
func classifyWithAI(textObservations: [TextObservation]) async -> ScreenshotType
```

**Implementation Comments:**
- Use `//` for explaining complex logic
- Avoid obvious comments ("increment counter")
- Explain WHY, not WHAT
- Keep comments near relevant code

## Function Design

**Size:** Prefer functions under 50 lines

**Parameters:**
- Max 3-4 parameters; use struct for related parameters
- Label all parameters except trailing closures
- Use consistent parameter order: input data first, then configuration

Example:
```swift
func post(
    url: URL,
    body: Data,
    headers: [String: String] = [:]
) async throws -> (Data, HTTPURLResponse)
```

**Return Values:**
- Return specific types, not generic optionals when possible
- Use tuples for multiple related return values: `(Data, HTTPURLResponse)`
- Use `Result<Success, Failure>` for operations that commonly fail
- Async functions returning `Void` omit return statement

## Module Design

**Exports:**
- Public APIs marked with public/internal access
- Implementation details marked private
- Protocols separate interface from implementation

Example from `ScreenshotClassifier.swift`:
```swift
// Protocol (interface)
protocol ScreenshotClassifierProtocol {
    func classify(textObservations: [TextObservation]) -> ScreenshotType
    func classifyWithAI(textObservations: [TextObservation]) async -> ScreenshotType
}

// Implementation
final class ScreenshotClassifier: ScreenshotClassifierProtocol, Sendable {
    // Details
}
```

**Configuration Enums:**
- Centralize constants in configuration enums: `ClassificationConfig`, `MovieMetadataConfig`, `AppTheme`
- Makes testing and maintenance easier

Example from `ScreenshotClassifier.swift`:
```swift
enum ClassificationConfig {
    static let minimumMatchThreshold = 1
    static let highConfidenceThreshold: Float = 0.8
    static let musicKeywords: Set<String> = [...]
}
```

## Type Safety & Concurrency

**Sendable Protocol:**
- Async types conform to `Sendable` for thread-safety: `final class ScreenshotClassifier: Sendable`
- Ensures type can be safely shared across async boundaries
- Mark types as `Sendable` when used with structured concurrency

**Actor Isolation:**
- Use `actor` for types managing shared mutable state: `actor APIClient`
- Provides automatic synchronization
- Main thread operations use `@MainActor`: `@MainActor @Observable final class ProcessingViewModel`

**SwiftUI Observation:**
- Use `@Observable` macro for view models
- Use `@State` for local view state
- Dependency injection in initializers

---

*Convention analysis: 2026-01-30*
