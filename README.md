# ScreenSort

An iOS app that automatically organizes your screenshots of music, movies, books, and memes using on-device AI.

## What It Does

ScreenSort scans your photo library for screenshots and intelligently categorizes them:

- **Music** - Screenshots from Spotify, Apple Music, Shazam, etc. are identified and songs can be added to your YouTube Music playlist
- **Movies/TV** - Screenshots from Netflix, IMDb, streaming apps are detected and matched with TMDb for metadata
- **Books** - Screenshots from Kindle, Goodreads, Apple Books are recognized and matched with Google Books
- **Memes** - Meme screenshots are detected and organized separately

All processing happens **on-device** using Apple Intelligence - your photos are never uploaded anywhere.

## Features

### AI-Powered Classification
- Uses Apple Intelligence (Foundation Models) for semantic understanding of screenshot content
- Falls back to keyword-based classification on older devices
- High accuracy detection of content type from OCR text

### Automatic Organization
- Creates dedicated albums for each content type (Music, Movies, Books, Memes, Flagged)
- Adds captions to processed screenshots with extracted metadata
- Logs processing results to Google Docs for record keeping

### Service Integration
- **YouTube Music** - Automatically adds detected songs to a playlist
- **TMDb** - Fetches movie/TV show metadata and posters
- **Google Books** - Retrieves book information and covers

### User Feedback Loop
- Review and correct misclassified screenshots
- Filter by category (All, Flagged, Music, Movies, Books, Memes)
- Corrections move photos to the correct album and update captions
- OCR snapshots stored for potential future learning

## Requirements

- iOS 18.1+ (for Apple Intelligence features)
- iPhone 15 Pro or later recommended (for on-device AI)
- Xcode 17.0+

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/mitgor/screensort.git
   cd screensort
   ```

2. Create your secrets configuration:
   ```bash
   cp Config/Secrets-Template.xcconfig Config/Secrets.xcconfig
   ```

3. Fill in your API keys in `Config/Secrets.xcconfig`:
   - `YOUTUBE_API_KEY` - YouTube Data API key
   - `YOUTUBE_CLIENT_ID` - YouTube OAuth client ID
   - `TMDB_BEARER_TOKEN` - TMDb API bearer token
   - `HARDCOVER_TOKEN` - Hardcover API token (optional)

4. Open `ScreenSort.xcodeproj` in Xcode

5. Build and run on your device

## Project Structure

```
ScreenSort/
├── Models/              # Data models (Metadata, Correction, etc.)
├── Services/            # Business logic and API integrations
│   ├── Protocols/       # Service interfaces for DI
│   ├── AIScreenshotClassifier.swift
│   ├── ScreenshotClassifier.swift
│   ├── MusicExtractor.swift
│   ├── MovieExtractor.swift
│   ├── BookExtractor.swift
│   ├── PhotoLibraryService.swift
│   ├── YouTubeService.swift
│   ├── TMDbService.swift
│   └── ...
├── ViewModels/          # Observable state management
├── Views/               # SwiftUI user interface
│   └── Components/      # Reusable UI components
├── Design/              # Design system and theming
└── Config/              # Build configuration
```

## Privacy

- All screenshot analysis happens on-device
- Photos are never uploaded to external servers
- Only metadata (song titles, movie names, etc.) is sent to third-party APIs for matching
- Photo library access is used only for reading screenshots and organizing into albums

## License

MIT License

## Author

Built with Claude Code
