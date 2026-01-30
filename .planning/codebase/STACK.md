# Technology Stack

**Analysis Date:** 2026-01-30

## Languages

**Primary:**
- Swift 5.9+ - Entire iOS application codebase
- SwiftUI - Modern UI framework (all views in `ScreenSort/Views/`)

**Secondary:**
- Objective-C runtime - System frameworks integration (Photos, Vision, AuthenticationServices)

## Runtime

**Environment:**
- iOS 18.1+ (required for Apple Intelligence features)
- iPhone 15 Pro or later recommended (on-device AI capability)

**Package Manager:**
- Swift Package Manager (SPM) - Built into Xcode, no external package manager used
- Lockfile: Not applicable (no third-party dependencies in package.json style)

## Frameworks

**Core UI & App:**
- SwiftUI - All user interface (`ScreenSort/Views/`)
- Foundation - Core data structures and utilities

**AI & Machine Learning:**
- FoundationModels (Apple Intelligence) - On-device classification in `ScreenSort/Services/AIScreenshotClassifier.swift`
  - Uses `@Generable` macro for structured output from language models
  - Minimum confidence threshold: 0.6

**Image & Vision Processing:**
- Vision Framework - OCR text extraction in `ScreenSort/Services/OCRService.swift`
  - Uses `VNRecognizeTextRequest` with accurate recognition level
  - Supports language correction and English language optimization

**Photo Library Access:**
- Photos Framework - Screenshot detection and album management in `ScreenSort/Services/PhotoLibraryService.swift`
  - PHAsset filtering for screenshots
  - Album creation and photo organization

**Authentication:**
- AuthenticationServices - OAuth web authentication in `ScreenSort/Services/AuthService.swift`
  - ASWebAuthenticationSession for secure OAuth flow
  - PKCE (Proof Key for Code Exchange) implementation using CryptoKit

**Security:**
- CryptoKit - PKCE code challenge generation (SHA256 hashing)
- Security.framework - Keychain access for token storage in `ScreenSort/Services/KeychainService.swift`

**Image Processing:**
- ImageIO - Image metadata reading

**Networking:**
- URLSession - HTTP requests with built-in caching in `ScreenSort/Services/APIClient.swift`
  - Custom URLCache: 20MB memory, 100MB disk
  - Cache policy: returnCacheDataElseLoad for GET requests
  - Includes automatic retry and error handling

## Key Dependencies

**Critical System Frameworks:**
- Photos - Photo library read/write access
- Vision - On-device OCR processing
- FoundationModels - Apple Intelligence for screenshot classification

**App-Level Services:**
- APIClient (`ScreenSort/Services/APIClient.swift`) - Centralized HTTP client with caching
- AuthService (`ScreenSort/Services/AuthService.swift`) - Google OAuth 2.0 with PKCE
- KeychainService (`ScreenSort/Services/KeychainService.swift`) - Secure token storage

**Content Extraction:**
- MusicExtractor (`ScreenSort/Services/MusicExtractor.swift`) - Music metadata extraction
- MovieExtractor (`ScreenSort/Services/MovieExtractor.swift`) - Movie metadata extraction
- BookExtractor (`ScreenSort/Services/BookExtractor.swift`) - Book metadata extraction

## Configuration

**Environment:**
- Build configuration via `.xcconfig` files in `Config/` directory
- API keys and tokens loaded from `Info.plist` at runtime:
  - `YOUTUBE_API_KEY` - YouTube Data API key
  - `YOUTUBE_CLIENT_ID` - YouTube OAuth client ID (set from Secrets.xcconfig)
  - `TMDB_BEARER_TOKEN` - TMDb API token (set from Secrets.xcconfig)
  - `HARDCOVER_TOKEN` - Optional Hardcover API token (set from Secrets.xcconfig)

**Secrets Management:**
- Template: `Config/Secrets-Template.xcconfig`
- Production: `Config/Secrets.xcconfig` (not committed to git)
- Values injected into `Info.plist` via build settings

**Build System:**
- Xcode 17.0+ required
- Xcode project: `ScreenSort.xcodeproj`
- Supports only iOS 18.1+ deployment target
- Requires code signing for device deployment

## Platform Requirements

**Development:**
- macOS 12.0+ with Xcode 17.0+
- iOS 18.1+ SDK
- Device or simulator with iPhone capability

**Production:**
- iOS 18.1+
- iPhone 15 Pro or later (for Apple Intelligence on-device processing)
- iCloud (optional, for photo sync)
- Network connectivity for external API calls (YouTube, TMDb, Google Books, Google Docs, Google Docs)

## Architecture Overview

**Design Pattern:**
- Service-oriented architecture with protocol-based dependency injection
- Protocol definitions in `ScreenSort/Services/Protocols/`
- Main service implementations in `ScreenSort/Services/`

**Threading Model:**
- @MainActor isolation for UI-related services
- Actor-based APIClient for thread-safe concurrent networking
- Async/await concurrency throughout

**Memory Management:**
- ARC (Automatic Reference Counting) with strong/weak reference management
- Image caching in APIClient (20MB memory, 100MB disk)

---

*Stack analysis: 2026-01-30*
