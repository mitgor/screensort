# Codebase Structure

**Analysis Date:** 2026-01-30

## Directory Layout

```
ScreenSort/
├── ScreenSort/                          # Main app source code
│   ├── ScreenSortApp.swift              # App entry point (@main)
│   ├── Design/                          # Design system and theming
│   │   └── DesignSystem.swift           # Centralized colors, spacing, shadows
│   ├── Models/                          # Domain models and data structures
│   │   ├── Screenshot.swift             # Photo library screenshot domain model
│   │   ├── ScreenshotType.swift         # Content type enumeration (music, movie, book, meme, unknown)
│   │   ├── MusicMetadata.swift          # Extracted music information
│   │   ├── MovieMetadata.swift          # Extracted movie information
│   │   ├── BookMetadata.swift           # Extracted book information
│   │   ├── Correction.swift             # User correction feedback model
│   │   ├── CorrectionReason.swift       # Why correction was made
│   │   ├── ProcessingResult.swift       # Processing outcome enumeration (legacy)
│   │   ├── ProcessingResultItem.swift   # Processing result for UI display
│   │   └── Errors.swift                 # Error type definitions
│   ├── Services/                        # Business logic and integrations
│   │   ├── Protocols/                   # Service interface definitions
│   │   │   ├── PhotoLibraryServiceProtocol.swift    # Photo library operations contract
│   │   │   ├── OCRServiceProtocol.swift             # Text recognition contract
│   │   │   ├── ScreenshotClassifierProtocol.swift   # Classification contract
│   │   │   ├── MusicExtractorProtocol.swift         # Music metadata extraction
│   │   │   ├── MovieExtractorProtocol.swift         # Movie metadata extraction
│   │   │   ├── BookExtractorProtocol.swift          # Book metadata extraction
│   │   │   ├── YouTubeServiceProtocol.swift         # YouTube API contract
│   │   │   ├── TMDbServiceProtocol.swift            # TMDb API contract
│   │   │   ├── GoogleBooksServiceProtocol.swift     # Google Books API contract
│   │   │   ├── GoogleDocsServiceProtocol.swift      # Google Docs logging contract
│   │   │   └── AuthServiceProtocol.swift            # OAuth contract
│   │   ├── PhotoLibraryService.swift     # Photo library access, album management
│   │   ├── OCRService.swift              # Vision framework text recognition
│   │   ├── ScreenshotClassifier.swift    # Keyword-based content classification
│   │   ├── AIScreenshotClassifier.swift  # Apple Intelligence classification
│   │   ├── MusicExtractor.swift          # AI-powered music metadata extraction
│   │   ├── MovieExtractor.swift          # AI-powered movie metadata extraction
│   │   ├── BookExtractor.swift           # AI-powered book metadata extraction
│   │   ├── MemeDetector.swift            # Meme content detection
│   │   ├── YouTubeService.swift          # YouTube search and playlist management
│   │   ├── TMDbService.swift             # Movie database search
│   │   ├── GoogleBooksService.swift      # Book search
│   │   ├── GoogleDocsService.swift       # Google Docs logging and sync
│   │   ├── AuthService.swift             # OAuth/authentication management
│   │   ├── KeychainService.swift         # Secure token storage
│   │   ├── APIClient.swift               # HTTP client (reusable)
│   │   ├── CorrectionService.swift       # Apply user corrections to library
│   │   └── CorrectionStore.swift         # Local correction persistence
│   ├── ViewModels/                      # App state and coordination
│   │   ├── ProcessingViewModel.swift     # Main workflow state and service orchestration
│   │   └── CorrectionReviewViewModel.swift  # Correction review state
│   ├── Views/                           # User interface layer
│   │   ├── ProcessingView.swift          # Main processing UI
│   │   ├── CorrectionReviewView.swift    # Correction review and feedback UI
│   │   ├── CorrectionSheet.swift         # Correction detail modal
│   │   ├── OnboardingView.swift          # Setup and permission flow
│   │   └── Components/                  # Reusable UI components
│   │       ├── AsyncThumbnailView.swift  # Async photo thumbnail loading
│   │       └── ReviewCard.swift          # Result card display component
│   └── Assets.xcassets/                 # App icons and images
├── ScreenSortTests/                     # Test suite
│   └── APIVerificationTests.swift       # API integration tests
├── ScreenSort.xcodeproj/                # Xcode project
├── README.md                            # App documentation
└── test-apis.swift                      # Manual API testing utility
```

## Directory Purposes

**Design/**
- Purpose: Centralized design tokens and theme
- Contains: Color definitions, spacing scales, shadow effects, accessibility
- Key files: `DesignSystem.swift` (single source of truth for styling)

**Models/**
- Purpose: Domain models and data structures (no business logic)
- Contains: Screenshots, metadata for each content type, processing results, corrections
- Key files:
  - `ScreenshotType.swift`: Drives routing, album names, UI icons
  - `MusicMetadata.swift`, `MovieMetadata.swift`, `BookMetadata.swift`: Validation and confidence scores
  - `Correction.swift`: Feedback collection
  - `ProcessingResultItem.swift`: UI display data

**Services/**
- Purpose: Business logic, API integration, system access
- Contains: Photo library operations, OCR, classification, AI extraction, external API calls, authentication
- Key files:
  - **Photo Library**: `PhotoLibraryService.swift` (album/caption operations), `CorrectionService.swift` (apply corrections)
  - **OCR & Classification**: `OCRService.swift`, `ScreenshotClassifier.swift`, `AIScreenshotClassifier.swift`
  - **Metadata Extraction**: `MusicExtractor.swift`, `MovieExtractor.swift`, `BookExtractor.swift`
  - **External APIs**: `YouTubeService.swift`, `TMDbService.swift`, `GoogleBooksService.swift`, `GoogleDocsService.swift`
  - **Auth & Storage**: `AuthService.swift`, `KeychainService.swift`, `CorrectionStore.swift`

**Services/Protocols/**
- Purpose: Define service contracts for dependency injection and testing
- Contains: All service interfaces (@MainActor where needed, async methods)
- Key pattern: Every service implementation has a corresponding protocol

**ViewModels/**
- Purpose: Bridge between Views and Services, manage state
- Contains: Observable state, service dependencies, business logic coordination
- Key files:
  - `ProcessingViewModel.swift`: Main workflow (46 lines of init, 18 service dependencies)
  - `CorrectionReviewViewModel.swift`: Correction filtering and application

**Views/**
- Purpose: User interface presentation and interaction
- Contains: SwiftUI views, navigation, animations, layout
- Key files:
  - `ProcessingView.swift`: Main interface (27705 bytes, largest view)
  - `CorrectionReviewView.swift`: Correction workflow UI
  - `CorrectionSheet.swift`: Detail modal for corrections
  - `OnboardingView.swift`: Initial setup
  - `Components/`: Reusable UI elements

**Assets.xcassets/**
- Purpose: App icons, images, and visual resources
- Generated: iOS builds add derived icons

## Key File Locations

**Entry Points:**
- `ScreenSort/ScreenSortApp.swift`: @main app entry, creates WindowGroup with ContentView
- `ScreenSort/Views/ProcessingView.swift`: Main view (navigation root)

**Configuration:**
- `ScreenSort/Design/DesignSystem.swift`: All design tokens
- `ScreenSort/Models/ScreenshotType.swift`: Content type configuration
- `ScreenSort/Services/ScreenshotClassifier.swift`: Classification keywords and thresholds
- `ScreenSort/Services/AIScreenshotClassifier.swift`: AI classification configuration (confidence thresholds)

**Core Logic:**
- `ScreenSort/ViewModels/ProcessingViewModel.swift`: Screenshot processing orchestration
- `ScreenSort/Services/PhotoLibraryService.swift`: Photo library access and management
- `ScreenSort/Services/ScreenshotClassifier.swift`: Content classification (keyword-based)
- `ScreenSort/Services/AIScreenshotClassifier.swift`: Content classification (AI-powered)

**Testing:**
- `ScreenSortTests/APIVerificationTests.swift`: API integration tests
- `test-apis.swift`: Manual testing utility

## Naming Conventions

**Files:**
- Service implementations: PascalCase + "Service" suffix (e.g., `YouTubeService.swift`)
- Extractors: PascalCase + "Extractor" suffix (e.g., `MusicExtractor.swift`)
- Protocol files: PascalCase + "Protocol" suffix (e.g., `PhotoLibraryServiceProtocol.swift`)
- View files: PascalCase + "View" suffix (e.g., `ProcessingView.swift`)
- ViewModel files: PascalCase + "ViewModel" suffix (e.g., `ProcessingViewModel.swift`)
- Model/struct files: PascalCase, descriptive names (e.g., `MusicMetadata.swift`, `Correction.swift`)

**Directories:**
- Feature areas: lowercase, descriptive (e.g., `Views`, `Services`, `Models`, `ViewModels`)
- Protocol subdirectory: `Services/Protocols/`
- Components subdirectory: `Views/Components/`

**Code Conventions:**
- Classes: PascalCase
- Structs: PascalCase
- Enums: PascalCase
- Functions/methods: camelCase
- Variables: camelCase
- Constants: camelCase (ClassificationConfig follows, but static members in enums)
- Type aliases: PascalCase
- Protocol names: PascalCase + "Protocol" suffix

## Where to Add New Code

**New Feature (e.g., new content type):**
1. Add case to `ScreenshotType` enum in `ScreenSort/Models/ScreenshotType.swift`
2. Create metadata struct in `ScreenSort/Models/` (e.g., `PodcastMetadata.swift`)
3. Create service in `ScreenSort/Services/` (e.g., `PodcastExtractor.swift`)
4. Create protocol in `ScreenSort/Services/Protocols/` (e.g., `PodcastExtractorProtocol.swift`)
5. Add protocol parameter to `ProcessingViewModel.__init()` in `ScreenSort/ViewModels/ProcessingViewModel.swift`
6. Add routing case in `ProcessingViewModel.processScreenshot()` switch statement
7. Add display in `CorrectionReviewView.swift` if correction review needed

**New Component/Subview:**
- Create in `ScreenSort/Views/Components/` for reusable UI
- Create in `ScreenSort/Views/` for standalone views with route
- Mark with `@MainActor` if it accesses ViewModels

**Utilities/Helpers:**
- Shared validation logic: Add to relevant Model file (e.g., `ExtractionValidator` in `MusicExtractor.swift`)
- Design helpers: Add to `ScreenSort/Design/DesignSystem.swift`
- Extension methods: Define near related types or in service files

**Configuration/Constants:**
- App-wide design: `ScreenSort/Design/DesignSystem.swift`
- Service thresholds: Define at top of service file (ClassificationConfig, AIClassificationConfig)
- Metadata validation: Define in model file (MusicMetadataConfig)

## Special Directories

**Assets.xcassets/**
- Purpose: iOS app icons and image assets
- Generated: Xcode builds add DerivedSources with GeneratedAssetSymbols.swift
- Committed: Yes (custom app icons)

**build/**
- Purpose: Xcode build artifacts
- Generated: Yes (Xcode creates during build)
- Committed: No (.gitignore)

**ScreenSort.xcodeproj/**
- Purpose: Xcode project configuration and workspace
- Generated: Partially (some files Xcode manages)
- Committed: Yes (project configuration)

---

*Structure analysis: 2026-01-30*
