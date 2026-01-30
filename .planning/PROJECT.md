# ScreenSort

## What This Is

An iOS app that automatically classifies and organizes screenshots using OCR and Apple Intelligence. It detects music, movies, books, and memes from screenshot content, extracts metadata, looks up additional info from external services (YouTube, TMDb, Google Books), organizes photos into albums, and logs everything to Google Docs.

## Core Value

Screenshots get classified and organized without manual effort — the app handles OCR, classification, metadata extraction, and album organization automatically.

## Requirements

### Validated

- ✓ OCR text extraction from screenshots using Vision framework — existing
- ✓ AI-powered classification (music, movie, book, meme, unknown) via Apple Intelligence — existing
- ✓ Keyword-based fallback classification for older devices — existing
- ✓ Music metadata extraction with YouTube playlist integration — existing
- ✓ Movie metadata extraction with TMDb lookup — existing
- ✓ Book metadata extraction with Google Books lookup — existing
- ✓ Photo album organization by content type — existing
- ✓ Google Docs logging of processed screenshots — existing
- ✓ Google OAuth authentication with PKCE — existing
- ✓ User correction flow for misclassified screenshots — existing
- ✓ Non-blocking processing with immediate feedback — v1.0
- ✓ Progress indicator with current/total count — v1.0
- ✓ Processing cancellation — v1.0
- ✓ Unknown screenshots stay in original location — v1.0
- ✓ Instant launch with cached results — v1.0
- ✓ Skeleton UI during fresh loads — v1.0
- ✓ Scroll position persistence — v1.0
- ✓ Processed screenshot tracking — v1.0
- ✓ Skip previously processed screenshots — v1.0
- ✓ Cache invalidation on photo deletion — v1.0

### Active

(None — awaiting next milestone definition)

### Out of Scope

- Offline mode for API lookups — requires significant caching infrastructure
- Batch correction UI — current single-item correction is sufficient
- Custom classification rules — hardcoded thresholds work for now
- Export to formats other than Google Docs — not requested
- Background processing when app is backgrounded — requires Background Tasks framework
- Undo for processed screenshots — complexity vs value tradeoff
- Manual album selection — automatic classification is core value
- iCloud sync of processing state — local-only is sufficient
- Notification when processing completes — app must be foregrounded

## Context

**Current state:** App shipped v1.0 UX Polish milestone with:
- 8,406 lines of Swift code
- 4 phases, 8 plans executed
- All 14 requirements satisfied
- Background processing, progress display, persistence, and instant launch

**Technical environment:**
- iOS 18.1+ required (Apple Intelligence)
- SwiftUI + MVVM architecture
- Protocol-based service layer
- No third-party dependencies

**Codebase map:** `.planning/codebase/` contains full analysis

## Constraints

- **Platform**: iOS 18.1+ only — Apple Intelligence requires this version
- **Device**: iPhone 15 Pro+ recommended for on-device AI
- **Architecture**: Must follow existing MVVM + protocol patterns
- **Storage**: Use UserDefaults or SwiftData for persistence (no external database)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Cache results list, not full app state | Simpler implementation, results are what users care about | ✓ Good |
| Leave unknown screenshots in place | User expectation — don't move things that weren't classified | ✓ Good |
| Track processed IDs, not full state | Skip duplicates without complexity of resumable processing | ✓ Good |
| Use UserDefaults for processed ID storage | Already used for corrections; consistent pattern | ✓ Good |
| Use .userInitiated QoS for OCR dispatch | User is waiting for results | ✓ Good |
| Stored Task reference for cancellation | Enables cancel button to stop processing | ✓ Good |
| Show skeleton only when isRefreshing AND results.isEmpty | Prevents flicker when cached data exists | ✓ Good |
| Save scroll position on disappear, not during scroll | Avoids excessive UserDefaults writes | ✓ Good |

---
*Last updated: 2026-01-30 after v1.0 milestone*
