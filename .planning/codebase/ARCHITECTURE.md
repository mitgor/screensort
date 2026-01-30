# Architecture

**Analysis Date:** 2026-01-30

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with protocol-based service layer

**Key Characteristics:**
- Clean separation between UI (Views), state management (ViewModels), and business logic (Services)
- Protocol-driven dependency injection for testability and loose coupling
- Centralized service orchestration through ViewModels
- Content type-specific processing pipelines (Music, Movie, Book, Meme)
- AI-enhanced classification with keyword fallback

## Layers

**Presentation Layer (Views):**
- Purpose: Display UI and collect user interaction
- Location: `ScreenSort/Views/` (main views), `ScreenSort/Views/Components/` (reusable components)
- Contains: SwiftUI views, animations, layout compositions
- Depends on: ViewModels, DesignSystem
- Used by: App entry point

**ViewModel Layer:**
- Purpose: Manage application state, coordinate services, expose reactive properties
- Location: `ScreenSort/ViewModels/`
- Contains: `ProcessingViewModel` (main workflow), `CorrectionReviewViewModel` (correction interface)
- Depends on: Service protocols, Models
- Used by: Views (via @State, @Observable)

**Service Layer:**
- Purpose: Implement business logic, external integrations, photo library operations, AI/OCR
- Location: `ScreenSort/Services/`
- Contains: Photo library access, OCR, classification, metadata extraction, Google Docs/YouTube APIs, authentication, correction application
- Depends on: Models, external frameworks (Photos, Vision, FoundationModels)
- Used by: ViewModels

**Protocol Layer:**
- Purpose: Define service contracts for dependency injection and testing
- Location: `ScreenSort/Services/Protocols/`
- Contains: All service interfaces (PhotoLibraryServiceProtocol, OCRServiceProtocol, etc.)
- Depends on: Models
- Used by: Services (implementation), ViewModels (injection)

**Model Layer:**
- Purpose: Define domain entities and configuration constants
- Location: `ScreenSort/Models/`
- Contains: Data structures (Screenshot, MusicMetadata, ProcessingResult, Correction), enums (ScreenshotType), error types
- Depends on: Foundation frameworks only
- Used by: All layers

**Design System:**
- Purpose: Centralized styling, colors, spacing, shadows
- Location: `ScreenSort/Design/DesignSystem.swift`
- Contains: Theme constants, color definitions, spacing scales
- Used by: All Views

## Data Flow

**Screenshot Processing Flow:**

1. **Initiation** → User taps "Process Now" in ProcessingView
   - ProcessingViewModel.processNow() starts async processing
   - UI prevents sleeping (UIApplication.isIdleTimerDisabled = true)

2. **Fetch** → PhotoLibraryService.fetchScreenshots()
   - Queries all screenshots from photo library
   - Filters out already-processed ones (caption check)
   - Returns array of PHAsset

3. **Preparation** → YouTube playlist creation, album preparation
   - YouTubeService.getOrCreatePlaylist() for music
   - PhotoLibraryService.createAlbumIfNeeded() for each ScreenshotType

4. **Classification** → For each screenshot:
   - OCRService.recognizeText() extracts text from image
   - ScreenshotClassifier.classifyWithAI() determines type:
     - Tries AIScreenshotClassifier (Apple Intelligence, if available)
     - Falls back to keyword-based ScreenshotClassifier
   - Returns ScreenshotType (music, movie, book, meme, unknown)

5. **Type-Specific Processing** → Routes to appropriate handler:
   - **Music** → MusicExtractor extracts metadata → YouTubeService searches/adds → logs to Google Docs
   - **Movie** → MovieExtractor extracts metadata → TMDbService searches → logs to Google Docs
   - **Book** → BookExtractor extracts metadata → GoogleBooksService searches → logs to Google Docs
   - **Meme** → Moves to meme album
   - **Unknown** → Moves to flagged album

6. **Result Persistence** → For each processed screenshot:
   - PhotoLibraryService.addAsset() moves to destination album
   - PhotoLibraryService.setCaption() stores result summary
   - GoogleDocsService.appendEntry() logs to Google Docs
   - ProcessingViewModel.results collects ProcessingResultItem

7. **Completion** → Re-enable device sleep, display results

**Correction Flow:**

1. User selects incorrect result in CorrectionReviewView
2. CorrectionReviewViewModel.applyCorrection() called with Correction
3. CorrectionService moves asset between albums
4. CorrectionService updates caption
5. CorrectionStore persists correction with reason (for future learning)
6. OCR snapshot stored with correction for AI training potential

**State Management:**

- **ProcessingViewModel** (@Observable @MainActor):
  - Maintains isProcessing, results, progress
  - Exposes computed properties (successCount, flaggedCount, etc.)
  - Coordinates all service calls in sequence
  - Stores OCR snapshots for correction review

- **CorrectionReviewViewModel** (@Observable @MainActor):
  - Filters results by ReviewFilter
  - Tracks selectedResult and showingCorrectionSheet
  - Applies corrections via CorrectionService

- **View State**:
  - Drives animations, transitions, sheet presentation
  - Derived from ViewModel observable properties

## Key Abstractions

**ScreenshotType Enum:**
- Purpose: Central enumeration for content categories
- Location: `ScreenSort/Models/ScreenshotType.swift`
- Pattern: Rich enum with computed properties (albumName, requiresExtraction, displayName, iconName)
- Used to determine processing path and UI presentation

**TextObservation Struct:**
- Purpose: OCR result wrapper with confidence and position
- Location: `ScreenSort/Services/Protocols/OCRServiceProtocol.swift`
- Pattern: Captures text, confidence score, bounding box for spatial analysis
- Used by: All classifiers and extractors

**Metadata Types:**
- `MusicMetadata` (`ScreenSort/Models/MusicMetadata.swift`): songTitle, artist, confidenceScore, rawText
- `MovieMetadata` (`ScreenSort/Models/MovieMetadata.swift`): title, year, creator, director
- `BookMetadata` (`ScreenSort/Models/BookMetadata.swift`): title, author, creator
- Pattern: Validate confidence thresholds, expose search queries
- Used by: Services before API calls

**ProcessingResultItem Struct:**
- Purpose: Accumulated result of processing a single screenshot
- Location: `ScreenSort/ViewModels/ProcessingViewModel.swift`
- Pattern: Contains status (success/flagged/failed), content type, metadata, service link
- Used by: Results display, correction review

**Correction Struct:**
- Purpose: Record user corrections for learning
- Location: `ScreenSort/Models/Correction.swift`
- Pattern: Stores original vs. corrected metadata, reason, OCR snapshot, applied status
- Used by: Correction workflows, feedback collection

**Classification Pipeline:**
- Purpose: Determine screenshot type with multiple confidence strategies
- Pattern:
  1. AIScreenshotClassifier (semantic analysis via Apple Intelligence)
  2. ScreenshotClassifier (keyword matching fallback)
  3. Classification thresholds (highConfidenceThreshold, minimumMatchThreshold)
- Files: `ScreenSort/Services/AIScreenshotClassifier.swift`, `ScreenSort/Services/ScreenshotClassifier.swift`

## Entry Points

**App Entry (ScreenSortApp):**
- Location: `ScreenSort/ScreenSortApp.swift`
- Triggers: App launch
- Responsibilities: Root window, ContentView initialization

**Processing View:**
- Location: `ScreenSort/Views/ProcessingView.swift`
- Triggers: Main navigation target
- Responsibilities:
  - Permission UI (photo library, YouTube auth)
  - Process button and progress display
  - Results display and review trigger

**Correction Review View:**
- Location: `ScreenSort/Views/CorrectionReviewView.swift`
- Triggers: User taps "Review & Correct" button
- Responsibilities:
  - Filter results by type
  - Display correction interface (old vs. new)
  - Apply corrections

## Error Handling

**Strategy:** Async/await try-catch with fallback chains

**Patterns:**

1. **Permission Errors** → Show permission cards, guide user action
2. **OCR Failures** → Return empty observations, classify as unknown
3. **Classification Failures** → Log to console, classify as unknown
4. **Extraction Failures** → Catch specific validation errors, move to flagged album
5. **API Errors** (YouTube, TMDb, Google Books, Google Docs) → Try operation, catch, include in result message
6. **Photo Library Errors** → Try album/caption operations, capture in exception handling
7. **Silent Fallbacks** → Metadata extraction may fail gracefully (no exception), item moves to flagged

Each extraction service (MusicExtractor, MovieExtractor, BookExtractor) validates AI response:
- File paths: `ScreenSort/Services/MusicExtractor.swift` (ExtractionValidator enum)
- Checks: Placeholder patterns, length requirements, confidence range

## Cross-Cutting Concerns

**Logging:**
- Ad-hoc print statements with emoji prefixes for visual scanning
- Pattern: "🎵 [ServiceName] Operation description"
- Files: Scattered throughout Services and ViewModels

**Validation:**
- Configuration enums (ClassificationConfig, MusicMetadataConfig, AIClassificationConfig)
- Files: `ScreenSort/Services/ScreenshotClassifier.swift`, `ScreenSort/Models/MusicMetadata.swift`, `ScreenSort/Services/AIScreenshotClassifier.swift`
- Used for: Thresholds, keyword lists, confidence requirements

**Authentication:**
- AuthService handles YouTube/Google OAuth
- Tokens stored in Keychain via KeychainService
- Files: `ScreenSort/Services/AuthService.swift`, `ScreenSort/Services/KeychainService.swift`

**Async Coordination:**
- TaskGroup for parallel album creation
- Async/await for all I/O
- @MainActor annotation on ViewModels and UI-touching services

---

*Architecture analysis: 2026-01-30*
