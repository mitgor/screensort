---
created: 2026-01-30T11:10
title: Add loading animation during screenshot processing
area: ui
files:
  - ScreenSort/Views/ProcessingView.swift
  - ScreenSort/ViewModels/ProcessingViewModel.swift
---

## Problem

When user presses button to process screenshots, app freezes for ~1 minute with no feedback. No indication of progress or how many screenshots remain. User has no way to know if app is working or hung.

## Solution

- Show progress indicator with current/total screenshot count
- Display animated loading state during processing
- Consider showing thumbnail of currently processing screenshot
- Ensure UI remains responsive during processing (async/background work)
