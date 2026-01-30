---
created: 2026-01-30T11:10
title: Keep unsorted/unknown screenshots in original folder
area: services
files:
  - ScreenSort/Services/PhotoLibraryService.swift
  - ScreenSort/Services/ScreenshotClassifier.swift
---

## Problem

Screenshots that cannot be classified (unknown type) are being moved or handled in a way that removes them from the screenshots folder. User expects unsorted screenshots to remain in place rather than being moved or deleted.

## Solution

- When classification returns unknown/unsorted, leave screenshot in original location
- Only move screenshots that have a definite classification
- Consider marking unknown screenshots internally for potential re-processing later
