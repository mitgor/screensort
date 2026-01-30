---
created: 2026-01-30T11:10
title: Save processing progress to track processed screenshots
area: services
files:
  - ScreenSort/Services/PhotoLibraryService.swift
  - ScreenSort/ViewModels/ProcessingViewModel.swift
---

## Problem

App has no memory of which screenshots have been processed vs which are new. Every session starts fresh, potentially re-processing the same screenshots. No way to resume interrupted processing or skip already-handled files.

## Solution

- Store processed screenshot identifiers (asset IDs or hashes) persistently
- On processing start, filter out already-processed screenshots
- Track processing state: pending, in-progress, completed, failed
- Allow resuming interrupted processing sessions
- Consider using CoreData or simple JSON file for persistence
