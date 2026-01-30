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

### Active

- [ ] Instant launch showing cached previous results
- [ ] Progress animation during screenshot processing with count display
- [ ] Keep unsorted/unknown screenshots in original location (don't move)
- [ ] Persist processed screenshot IDs to skip on subsequent runs

### Out of Scope

- Offline mode for API lookups — requires significant caching infrastructure
- Batch correction UI — current single-item correction is sufficient
- Custom classification rules — hardcoded thresholds work for now
- Export to formats other than Google Docs — not requested

## Context

**Current state:** App works end-to-end but has UX friction:
- App freezes during processing with no feedback (~1 minute)
- Cold launch shows nothing until initialization completes
- Unknown screenshots get moved to "Flagged" album instead of staying put
- Every launch reprocesses all screenshots (no memory of what's done)

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
| Cache results list, not full app state | Simpler implementation, results are what users care about | — Pending |
| Leave unknown screenshots in place | User expectation — don't move things that weren't classified | — Pending |
| Track processed IDs, not full state | Skip duplicates without complexity of resumable processing | — Pending |
| Use UserDefaults for processed ID storage | Already used for corrections; consistent pattern | — Pending |

---
*Last updated: 2026-01-30 after initialization*
