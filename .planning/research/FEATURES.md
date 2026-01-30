# Feature Landscape: iOS UX Polish for ScreenSort

**Domain:** iOS photo organization app with AI classification
**Researched:** 2026-01-30
**Focus Areas:** Loading states, progress feedback, handling unclassifiable items

## Table Stakes

Features users expect. Missing = product feels incomplete or broken.

### 1. Loading & Progress Feedback

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Visual activity indication** | Apple HIG states users perceive static screens as frozen/stalled. Without feedback, users leave. | Low | Minimum: activity spinner. Better: progress bar. |
| **Determinate progress for batch operations** | Users can gauge wait time. Research shows users wait 3x longer with progress indicators (22.6s vs 9s median). | Low | Use ProgressView with explicit progress value for quantifiable tasks. |
| **Progress count display** | "3 of 47 screenshots" lets users plan their time and confirms app is working. | Low | Already implemented; essential baseline. |
| **Responsive UI during processing** | App must not freeze. Users expect to scroll, read results, or navigate while processing. | Med | Current ~1 minute freeze is a critical failure. Must use background processing. |
| **Cancel operation capability** | Users must be able to stop long-running tasks. Inability to cancel is a fundamental UX problem. | Med | Provide clear cancel button during processing. |

### 2. Perceived Performance

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Instant launch appearance** | Apple HIG: Launch screen should look identical to first screen; app should feel "instantly ready." | Low | Launch screen matches first frame of app. |
| **Sub-100ms interactions feel instant** | Interactions under 100ms need no loading indicator. | N/A | Design guideline, not a feature. |
| **Feedback within 1 second** | Any action taking >1 second needs visual acknowledgment. | Low | Show inline spinner or state change. |
| **Skeleton screens for content loading** | Users report 30% faster perceived performance with skeleton screens vs blank states. | Med | Use for results list, thumbnail loading. |

### 3. Handling Unknown/Unclassifiable Items

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Don't auto-move unknowns without consent** | Users stated they want unknown items to stay in place. Moving without asking violates user expectations. | Med | Key finding: Current behavior moves to "Flagged" album, which users dislike. |
| **Clear indication of uncertainty** | AI classification UX research: Users are comfortable with uncertainty when clearly communicated. | Low | Show "Could not classify" with visual distinction (color, icon). |
| **Review workflow for ambiguous items** | Users need a path to resolve unknowns manually. Already implemented via CorrectionReviewView. | Low | Existing feature; ensure it's discoverable. |
| **Confidence visualization** | Best practice: Color-code confidence (green >= 85%, yellow 60-84%, red < 60%). | Med | Consider showing classification confidence in review UI. |

### 4. Completion Feedback

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Success haptic on completion** | iOS convention: `.success` haptic from UINotificationFeedbackGenerator indicates task completion. | Low | Use `sensoryFeedback(.success)` when batch finishes. |
| **Summary of results** | Users need to know what happened. Show counts by type, any failures. | Low | Already implemented in results section. |
| **Ability to undo/revert** | Apple Photos shows "Revert to Original" for batch edits. Users expect escape hatch. | Med | Consider "Revert" option for processed screenshots. |

## Differentiators

Features that set the product apart. Not expected, but create delight.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Animated progress ring** | More engaging than standard progress bar. Already implemented with ProgressRing. | Low | Existing feature; enhance with subtle animation. |
| **Per-item status in real-time** | Show each screenshot result as it processes, not just at end. | Med | Current implementation appends results in real-time; good. |
| **Dynamic Island / Live Activity** | iOS 26 BGContinuedProcessingTask allows background work with Live Activity progress. Users can leave app and still see progress. | High | iOS 26 feature: Shows progress on lock screen, background processing continues. |
| **Incremental results while processing** | User can see and interact with completed results before batch finishes. | Med | Would improve perceived responsiveness. |
| **Hierarchical haptics during progress** | Subtle haptic feedback at milestones (e.g., every 10 items or phase transitions). | Low | Creates sense of progress; used by iOS pan gestures. |
| **"Leave in place" option for unknowns** | Rather than move to Flagged album, offer option to skip/leave unclassified items untouched. | Med | Directly addresses user feedback about unwanted moves. |
| **Confidence score display** | Show how certain the AI is about classifications. Builds trust and helps prioritize review. | Med | "High confidence" / "Low confidence" labels or subtle visual indicators. |
| **Batch retry for failed items** | After processing, offer "Retry failed" button instead of re-processing everything. | Med | Saves time; respects user's data already processed. |

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Moving files without user consent** | Users explicitly stated they don't want unknown items moved. Auto-organizing without permission destroys trust. | Ask first, or provide "leave in place" default for unknowns. |
| **Animated splash screen as delay tactic** | Apple HIG explicitly discourages using launch screen as branding opportunity. Users perceive it as slow. | Match launch screen to first app frame; minimize launch time. |
| **Blocking UI during processing** | Current ~1 minute freeze makes app feel broken. Users can't cancel, scroll, or do anything. | Process in background; keep UI responsive; provide cancel. |
| **Raw confidence decimals** | Showing "0.73" or "73%" looks technical and confusing to users. | Use "High/Medium/Low confidence" labels or simple visual cues. |
| **Hiding low-confidence outputs** | Faking confidence by hiding uncertain results destroys long-term trust. | Always show uncertain items; let user decide what to do. |
| **Warning dialogs for reversible actions** | Research shows users click through warnings habitually. Warnings don't prevent mistakes. | Use undo instead of warnings; let users fix mistakes after the fact. |
| **Indeterminate spinner for quantifiable work** | When you know the total (N screenshots), an indeterminate spinner frustrates users. | Use determinate progress bar showing X of N. |
| **Over-animating during heavy processing** | AnimatedBackground during processing can compete for resources and feel sluggish. | Already implemented: `AnimatedBackground(isAnimating: !viewModel.isProcessing)`. Good pattern. |

## Feature Dependencies

```
Responsive UI during processing
    |
    +-- Background processing architecture (prerequisite)
    |
    +-- Cancel operation capability
    |
    +-- Incremental results display

"Leave in place" option
    |
    +-- Settings/preferences infrastructure
    |
    +-- Modified processUnknownScreenshot logic

Dynamic Island / Live Activity
    |
    +-- BGContinuedProcessingTask (iOS 26+)
    |
    +-- Progress reporting infrastructure
```

## Prioritized Recommendations

### Phase 1: Critical Fixes (Table Stakes)

1. **Fix UI freeze during processing** - This is the #1 issue. Move processing off main thread, keep UI responsive.
2. **Add cancel capability** - Users must be able to stop a 1-minute operation.
3. **Success haptic on completion** - Low effort, immediate UX improvement.

### Phase 2: Unknown Handling Improvements

1. **"Leave in place" default for unknowns** - Directly addresses user feedback. Don't move to Flagged without consent.
2. **Clear uncertainty indication** - Color-code or label low-confidence classifications.
3. **Improved review discoverability** - Make "Review & Correct" button more prominent when unknowns exist.

### Phase 3: Polish & Delight

1. **Skeleton screens for results** - Improve perceived performance during loading.
2. **Confidence visualization** - Build trust through transparency.
3. **Batch retry for failures** - Quality-of-life improvement.

### Defer to Later

- **Dynamic Island / Live Activity** - iOS 26 feature, higher complexity, nice-to-have.
- **Undo/revert for processed items** - Useful but complex; requires tracking original state.

## Sources

### Apple Official (HIGH confidence)

- [Loading - Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/loading)
- [Progress Indicators - Apple HIG](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
- [Launching - Apple HIG](https://developer.apple.com/design/human-interface-guidelines/launching)
- [Feedback - Apple HIG](https://developer.apple.com/design/human-interface-guidelines/feedback)
- [ProgressView - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/progressview)
- [BGContinuedProcessingTask - WWDC 2025](https://developer.apple.com/videos/play/wwdc2025/227/)

### Research & UX Patterns (MEDIUM confidence)

- [Skeleton Loading Screen Design - LogRocket](https://blog.logrocket.com/ux-design/skeleton-loading-screen-design/) - 30% faster perceived performance with skeleton screens
- [Confidence Visualization UI Patterns - Agentic Design](https://agentic-design.ai/patterns/ui-ux-patterns/confidence-visualization-patterns) - Color-coded thresholds for AI confidence
- [Progress Trackers and Indicators - UserGuiding](https://userguiding.com/blog/progress-trackers-and-indicators) - Users wait 22.6s with progress bar vs 9s without
- [Cancel vs Close - Nielsen Norman Group](https://www.nngroup.com/articles/cancel-vs-close/) - Distinction between cancel and close operations
- [Never Use a Warning When You Mean Undo - A List Apart](https://alistapart.com/article/neveruseawarning/) - Why undo beats warning dialogs

### iOS Haptics & Implementation (MEDIUM confidence)

- [Haptic Feedback in iOS - Medium](https://medium.com/@mi9nxi/haptic-feedback-in-ios-a-comprehensive-guide-6c491a5f22cb)
- [Mastering ProgressView in SwiftUI - Medium](https://medium.com/@wesleymatlock/mastering-progressview-in-swiftui-advanced-techniques-tips-and-tricks-265c9f2de6a8)
- [Custom Skeleton Loading in SwiftUI - Medium](https://medium.com/@thiagorodriguescenturion/stop-using-progressview-custom-skeleton-loading-in-swiftui-83682ca7a13e)

### Photo Organization Apps (LOW confidence - competitor patterns)

- [Utiful Photo Organizer](https://www.utifulapp.com/) - Example of "move photos out of camera roll" pattern
- [Slidebox](https://apps.apple.com/us/app/slidebox-photo-manager/id984305203) - Swipe-based photo organization UX
- iOS Photos batch editing (iOS 16+) - Shows progress bar with "Paste Edits Completed" confirmation
