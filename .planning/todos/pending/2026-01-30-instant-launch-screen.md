---
created: 2026-01-30T11:10
title: Add instant launch screen with cached state
area: ui
files:
  - ScreenSort/ScreenSortApp.swift
  - ScreenSort/ContentView.swift
---

## Problem

App currently shows nothing meaningful on launch while initializing. User experiences a blank or loading state before the app becomes usable. Should save the last visible screen state and restore it instantly on launch for perceived instant startup.

## Solution

- Save last visible screen state (view hierarchy, data snapshot) to UserDefaults or file on app background/termination
- Restore cached state immediately on launch before async initialization completes
- Fade/transition to live data once ready
