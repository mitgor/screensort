# External Integrations

**Analysis Date:** 2026-01-30

## APIs & External Services

**Google OAuth 2.0:**
- Purpose: Unified authentication for YouTube, Google Docs, Google Drive, and Google Books
- SDK/Client: AuthenticationServices (native iOS)
- Auth: PKCE-based OAuth 2.0 flow with refresh tokens
- Implementation: `ScreenSort/Services/AuthService.swift`
- Redirect URI: `com.screensort:/oauth2callback`
- Scopes:
  - `https://www.googleapis.com/auth/youtube` - YouTube playlist access
  - `https://www.googleapis.com/auth/documents` - Google Docs read/write
  - `https://www.googleapis.com/auth/drive.file` - Google Drive file access
  - `https://www.googleapis.com/auth/books` - Google Books API access

**YouTube Data API v3:**
- What it's used for: Search for songs, manage playlists, add videos to user playlists
- Base URL: `https://www.googleapis.com/youtube/v3`
- SDK/Client: `ScreenSort/Services/YouTubeService.swift` with custom APIClient
- Auth: OAuth 2.0 Bearer token for authenticated operations, API key for public search
- Key operations:
  - Song search: `/search` endpoint with music category filter (categoryId: "10")
  - Playlist management: `/playlists` and `/playlistItems` endpoints
  - Throttling: Respects YouTube quota system (handles 403 quotaExceeded)
- Environment variable: `YOUTUBE_API_KEY` (from Bundle/Info.plist)
- Error handling: Custom `YouTubeError` enum with token expiration, quota, and network errors

**TMDb (The Movie Database) API:**
- What it's used for: Movie/TV show metadata search, poster retrieval, linking
- Base URL: `https://api.themoviedb.org/3`
- SDK/Client: `ScreenSort/Services/TMDbService.swift`
- Auth: API key (bearer token style) in URL query parameters
- Environment variable: `TMDB_BEARER_TOKEN` (checked in Info.plist)
- Configuration status: Service validates API key presence and format before use
- Endpoints:
  - Movie search: `/search/movie` with title, year, language filters
  - Results: Returns first match with title, year, poster path, TMDb URL
- Caching: returnCacheDataElseLoad (cache enabled)

**Google Books API:**
- What it's used for: Book metadata search, book cover images, author information
- Base URL: `https://www.googleapis.com/books/v1/volumes`
- SDK/Client: `ScreenSort/Services/GoogleBooksService.swift`
- Auth: OAuth 2.0 Bearer token (via AuthService)
- Query syntax: Google Books query language with `intitle:` and `inauthor:` operators
- Endpoints:
  - Volume search: `/volumes` with query string, maxResults, printType filters
  - Results: Book title, authors, ISBN, thumbnails, info links
- Caching: returnCacheDataElseLoad (cache enabled)
- Error handling: Returns notAuthenticated (401/403), noResultsFound, invalidResponse

**Google Docs API v1:**
- What it's used for: Logging recognized content and processing results to a Google Doc
- Base URLs:
  - Documents: `https://docs.googleapis.com/v1/documents`
  - Drive: `https://www.googleapis.com/drive/v3/files`
- SDK/Client: `ScreenSort/Services/GoogleDocsService.swift`
- Auth: OAuth 2.0 Bearer token (via AuthService)
- Implementation: `ScreenSort/Services/GoogleDocsService.swift` (14KB, complex)
  - Document title: "ScreenSort - Recognized Content"
  - Cached document ID for session
  - In-memory entry deduplication
  - Batch content updates
- Operations:
  - Find/create document by title
  - Append formatted entries (metadata, links, timestamps)
  - Generate shareable document URL
- Error handling: Custom `GoogleDocsError` with retry logic for network errors

**Optional: Hardcover API:**
- What it's used for: Alternative book metadata source (currently optional)
- Environment variable: `HARDCOVER_TOKEN` (optional in Info.plist)
- Status: Integrated but not critical

## Data Storage

**Databases:**
- Not applicable - no traditional database
- All state is in-app ephemeral or stored in iOS keychain/user defaults

**Local Storage:**
- iOS Photo Library - Only interface for persistent storage
  - Albums created by app for organization
  - Photos never copied or modified, only organized into albums
  - Access: PhotoLibraryService (`ScreenSort/Services/PhotoLibraryService.swift`)

**File Storage:**
- Local filesystem only - Photos remain in iOS Photo Library
- No external cloud storage used for photos
- OCR snapshots stored locally for potential future learning (in-app only)

**Caching:**
- URLSession disk cache (100MB max, 20MB memory)
  - Configured in `ScreenSort/Services/APIClient.swift`
  - Stores API responses for search results
  - GET requests use cache-then-network, POST requests bypass cache

## Authentication & Identity

**Auth Provider:**
- Google OAuth 2.0 (single sign-on for all Google services)
- Implementation: `ScreenSort/Services/AuthService.swift` with PKCE flow

**Token Management:**
- Storage: Secure Keychain via `ScreenSort/Services/KeychainService.swift`
- Tokens: Access token + refresh token
- Refresh: AuthService automatically refreshes expired tokens
- Access method: `getValidAccessToken()` returns current valid token

**Session Management:**
- OAuth callback scheme: `com.screensort:/oauth2callback`
- Registered in Info.plist CFBundleURLSchemes
- PKCE code verifier: 32 bytes random, base64url encoded
- Token lifecycle: Access token + refresh token stored persistently

## Monitoring & Observability

**Error Tracking:**
- Not integrated - errors logged locally only
- Error models: Custom error enums in `ScreenSort/Models/Errors.swift` (21KB)
  - YouTube errors: tokenExpired, quotaExceeded, noResultsFound, searchFailed
  - TMDb errors: notConfigured, noResultsFound, invalidResponse
  - Google Books errors: notAuthenticated, noResultsFound, invalidResponse
  - Google Docs errors: notAuthenticated, documentNotFound, createFailed, updateFailed, networkError

**Logs:**
- Debug logging only - no production telemetry
- Console output for development
- No remote logging or analytics

## CI/CD & Deployment

**Hosting:**
- None - iOS app, installed on user device
- Distributed via App Store or TestFlight

**CI Pipeline:**
- Not detected - Xcode build system only

**Deployment:**
- Manual via Xcode or Xcode Cloud (if configured)
- Requires code signing with Apple developer certificate

## Environment Configuration

**Required env vars (in Secrets.xcconfig):**
- `YOUTUBE_API_KEY` - YouTube Data API v3 key (public key for search)
- `YOUTUBE_CLIENT_ID` - Google OAuth client ID (for YouTube/Docs/Books/Drive scopes)
- `TMDB_BEARER_TOKEN` - TMDb API bearer token (optional but recommended)
- `HARDCOVER_TOKEN` - Hardcover API token (optional)

**Build-time configuration:**
- Loaded from `Config/Secrets.xcconfig` via build settings
- Injected into Info.plist during build
- Bundle.main reads at runtime: `Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY")`

**Secrets location:**
- Template: `/Users/mit/ScreenSort/Config/Secrets-Template.xcconfig`
- Production: `/Users/mit/ScreenSort/Config/Secrets.xcconfig` (git-ignored)
- Instructions in README.md setup section

## Webhooks & Callbacks

**Incoming:**
- OAuth callback: `com.screensort:/oauth2callback` - Receives authorization code from Google OAuth
- Photo Library changes: Observed via PHPhotoLibrary change notifications (internal only)

**Outgoing:**
- None - App is read-only for external services (except OAuth callback)

## Rate Limiting & Quotas

**YouTube API:**
- Daily quota: 10,000 units per day (default for YouTube Data API)
- Per-operation cost:
  - Search: 100 units
  - Playlist operations: 50-100 units
- Handling: Service detects 403 quotaExceeded and throws `YouTubeError.quotaExceeded`

**TMDb API:**
- Rate limit: 40 requests per 10 seconds per IP
- No explicit handling beyond standard HTTP error responses

**Google APIs:**
- Shared quota across Google services
- No explicit rate limiting implemented in code

## Security Considerations

**Data in Transit:**
- HTTPS only for all external API calls
- OAuth uses secure PKCE flow (SHA256 code challenge)
- Bearer tokens in Authorization header only

**Data at Rest:**
- OAuth tokens stored in iOS Keychain (encrypted)
- No API keys stored in code (loaded from build config)
- Photo data never leaves device

**Privacy:**
- Photos never uploaded to external servers
- Only extracted metadata (titles, names, links) sent to APIs
- No analytics or tracking
- Privacy manifest: `ScreenSort/PrivacyInfo.xcprivacy`

---

*Integration audit: 2026-01-30*
