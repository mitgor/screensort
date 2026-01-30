# Roadmap: ScreenSort UX Polish

## Overview

ScreenSort has working AI-powered screenshot classification but suffers from a critical UI freeze during processing. This roadmap transforms the user experience from "app freezes for a minute" to "instant launch with smooth progress feedback." Four phases address the freeze bug, add progress indicators, implement persistence, and polish the launch experience.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4): Planned milestone work
- Decimal phases (e.g., 2.1): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Fix UI Freeze** - Make processing non-blocking with cancel support
- [x] **Phase 2: Progress Indicators** - Show processing progress with count display
- [x] **Phase 3: State Persistence** - Track processed screenshots, persist results
- [x] **Phase 4: Launch Experience** - Instant launch with cached results

## Phase Details

### Phase 1: Fix UI Freeze
**Goal**: Users can use the app normally while screenshots process in the background
**Depends on**: Nothing (first phase)
**Requirements**: PROC-01, PROC-03, PROC-04, ORG-01, ORG-02
**Success Criteria** (what must be TRUE):
  1. User can scroll the results list while processing runs
  2. User can tap cancel and processing stops within 2 seconds
  3. User sees immediate visual feedback when processing starts (no freeze)
  4. Unknown/unclassifiable screenshots remain in their original album
  5. Only successfully classified screenshots are moved to destination albums
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Move Vision OCR to background thread
- [x] 01-02-PLAN.md — Add cancellation support, fix unknown handling, add cancel button

### Phase 2: Progress Indicators
**Goal**: Users know exactly how many screenshots have been processed and how many remain
**Depends on**: Phase 1 (requires non-blocking architecture for smooth updates)
**Requirements**: PROC-02
**Success Criteria** (what must be TRUE):
  1. User sees "X of Y screenshots" count during processing
  2. Progress indicator updates smoothly without UI stutter
  3. User receives haptic feedback when processing completes
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md — Add native ProgressView and completion haptic

### Phase 3: State Persistence
**Goal**: Processing results survive app termination; previously processed screenshots are skipped
**Depends on**: Phase 1 (uses non-blocking architecture)
**Requirements**: PERSIST-01, PERSIST-02, PERSIST-03, PERSIST-04
**Success Criteria** (what must be TRUE):
  1. User kills app during processing, relaunches, and sees results from before termination
  2. User processes 50 screenshots, relaunches, and reprocessing skips all 50
  3. User deletes source screenshots, and stale cached results are cleaned up
  4. Processed screenshot IDs persist across app launches
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — Create ProcessedScreenshotStore and add Codable conformance
- [x] 03-02-PLAN.md — Integrate persistence into ProcessingViewModel

### Phase 4: Launch Experience
**Goal**: App launches instantly with previous results visible; loading state is polished
**Depends on**: Phase 3 (requires persistence layer for cached results)
**Requirements**: LAUNCH-01, LAUNCH-02, LAUNCH-03
**Success Criteria** (what must be TRUE):
  1. User launches app and immediately sees previous session's results (no loading delay)
  2. User sees skeleton/placeholder UI while fresh data loads in background
  3. User's scroll position from previous session is restored on launch
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — Add skeleton loading UI with shimmer for results section
- [x] 04-02-PLAN.md — Implement scroll position persistence
- [x] 04-03-PLAN.md — Wire isRefreshing flag and add background refresh (gap closure)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fix UI Freeze | 2/2 | Complete | 2026-01-30 |
| 2. Progress Indicators | 1/1 | Complete | 2026-01-30 |
| 3. State Persistence | 2/2 | Complete | 2026-01-30 |
| 4. Launch Experience | 3/3 | Complete | 2026-01-30 |

---
*Last updated: 2026-01-30 after Phase 4 verification passed*
