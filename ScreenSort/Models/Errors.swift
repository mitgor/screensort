//
//  Errors.swift
//  ScreenSort
//
//  Defines domain-specific error types with user-friendly messages
//  and recovery suggestions.
//

import Foundation

// MARK: - Error Protocol Extensions

/// Protocol for errors that can suggest recovery actions to users.
protocol RecoverableError: LocalizedError {
    /// A suggestion for how the user might resolve this error.
    var recoverySuggestion: String? { get }

    /// Whether this error might be resolved by retrying the operation.
    var isRetryable: Bool { get }
}

// MARK: - Photo Library Errors

/// Errors related to Photos framework operations.
enum PhotoLibraryError: Error, RecoverableError {
    /// User denied photo library access permission.
    case accessDenied

    /// Limited access mode does not support the requested operation.
    case limitedAccessUnsupported

    /// Failed to create a photo album.
    case albumCreationFailed(reason: String)

    /// The requested photo asset no longer exists in the library.
    case assetNotFound

    /// Failed to move a photo to an album.
    case moveToAlbumFailed(reason: String)

    /// Failed to update photo caption.
    case captionUpdateFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access was denied."
        case .limitedAccessUnsupported:
            return "This operation requires full photo library access."
        case .albumCreationFailed(let reason):
            return "Failed to create album: \(reason)"
        case .assetNotFound:
            return "The photo could not be found."
        case .moveToAlbumFailed(let reason):
            return "Failed to organize photo: \(reason)"
        case .captionUpdateFailed(let reason):
            return "Failed to update photo caption: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Open Settings > Privacy > Photos and grant ScreenSort access."
        case .limitedAccessUnsupported:
            return "Open Settings > Privacy > Photos and select 'Full Access'."
        case .albumCreationFailed:
            return "Try again or restart the app."
        case .assetNotFound:
            return "The photo may have been deleted. Refresh and try again."
        case .moveToAlbumFailed:
            return "Check that the photo still exists and try again."
        case .captionUpdateFailed:
            return "Caption feature uses undocumented API. Try again or skip captions."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .accessDenied, .limitedAccessUnsupported:
            return false  // Requires settings change
        case .albumCreationFailed, .moveToAlbumFailed, .captionUpdateFailed:
            return true
        case .assetNotFound:
            return false  // Asset is gone
        }
    }
}

// MARK: - OCR Errors

/// Errors from Vision framework text recognition.
enum OCRError: Error, RecoverableError {
    /// The image could not be processed (invalid format or corrupted).
    case invalidImage

    /// No text was detected in the image.
    case noTextFound

    /// Text recognition failed with a specific reason.
    case recognitionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image."
        case .noTextFound:
            return "No text was found in the image."
        case .recognitionFailed(let reason):
            return "Text recognition failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "The image may be corrupted. Try a different screenshot."
        case .noTextFound:
            return "Ensure the screenshot shows visible text from a music app."
        case .recognitionFailed:
            return "Try again with a clearer screenshot."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .invalidImage:
            return false
        case .noTextFound, .recognitionFailed:
            return true
        }
    }
}

// MARK: - Music Extraction Errors

/// Errors from AI-powered music metadata extraction.
enum MusicExtractionError: Error, RecoverableError {
    /// The screenshot does not appear to be from a music app.
    case notMusicScreenshot

    /// Could not identify a song title in the screenshot.
    case songTitleNotFound

    /// Could not identify an artist name in the screenshot.
    case artistNotFound

    /// Extraction confidence is below the required threshold.
    case confidenceTooLow(score: Float, threshold: Float)

    /// The AI model is not available on this device.
    case modelUnavailable

    /// The extraction result contained placeholder or invalid data.
    case invalidExtractionResult(reason: String)

    var errorDescription: String? {
        switch self {
        case .notMusicScreenshot:
            return "This does not appear to be a music screenshot."
        case .songTitleNotFound:
            return "Could not identify the song title."
        case .artistNotFound:
            return "Could not identify the artist."
        case .confidenceTooLow(let score, let threshold):
            let scorePercent = Int(score * 100)
            let thresholdPercent = Int(threshold * 100)
            return "Extraction confidence (\(scorePercent)%) is below the \(thresholdPercent)% threshold."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .invalidExtractionResult(let reason):
            return "Invalid extraction result: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notMusicScreenshot:
            return "Only screenshots from music apps (Spotify, Apple Music, etc.) are supported."
        case .songTitleNotFound, .artistNotFound:
            return "Try a screenshot where the song and artist are clearly visible."
        case .confidenceTooLow:
            return "Try a clearer screenshot with the song title prominently displayed."
        case .modelUnavailable:
            return "This feature requires an iPhone 15 Pro or newer with iOS 18.1+."
        case .invalidExtractionResult:
            return "Try again with a different screenshot."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .modelUnavailable:
            return false  // Hardware/software limitation
        case .notMusicScreenshot, .songTitleNotFound, .artistNotFound,
             .confidenceTooLow, .invalidExtractionResult:
            return true
        }
    }
}

// Backward compatibility alias for existing code
extension MusicExtractionError {
    /// Alias for backward compatibility with existing error handling.
    static func couldNotParseSongTitle() -> MusicExtractionError {
        .songTitleNotFound
    }

    /// Alias for backward compatibility with existing error handling.
    static func couldNotParseArtist() -> MusicExtractionError {
        .artistNotFound
    }

    /// Alias for backward compatibility - maps old confidence error to new format.
    static func confidenceTooLow(_ score: Float) -> MusicExtractionError {
        .confidenceTooLow(score: score, threshold: MusicMetadataConfig.highConfidenceThreshold)
    }
}

// MARK: - Movie Extraction Errors

/// Errors from AI-powered movie metadata extraction.
enum MovieExtractionError: Error, RecoverableError {
    /// The screenshot does not appear to be from a movie/streaming app.
    case notMovieScreenshot

    /// Could not identify a movie title in the screenshot.
    case movieTitleNotFound

    /// Could not identify a director name in the screenshot.
    case directorNotFound

    /// Extraction confidence is below the required threshold.
    case confidenceTooLow(score: Float, threshold: Float)

    /// The AI model is not available on this device.
    case modelUnavailable

    /// The extraction result contained placeholder or invalid data.
    case invalidExtractionResult(reason: String)

    var errorDescription: String? {
        switch self {
        case .notMovieScreenshot:
            return "This does not appear to be a movie screenshot."
        case .movieTitleNotFound:
            return "Could not identify the movie title."
        case .directorNotFound:
            return "Could not identify the director."
        case .confidenceTooLow(let score, let threshold):
            let scorePercent = Int(score * 100)
            let thresholdPercent = Int(threshold * 100)
            return "Extraction confidence (\(scorePercent)%) is below the \(thresholdPercent)% threshold."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .invalidExtractionResult(let reason):
            return "Invalid extraction result: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notMovieScreenshot:
            return "Only screenshots from streaming apps (Netflix, Prime Video, etc.) are supported."
        case .movieTitleNotFound, .directorNotFound:
            return "Try a screenshot where the movie title is clearly visible."
        case .confidenceTooLow:
            return "Try a clearer screenshot with the movie title prominently displayed."
        case .modelUnavailable:
            return "This feature requires an iPhone 15 Pro or newer with iOS 18.1+."
        case .invalidExtractionResult:
            return "Try again with a different screenshot."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .modelUnavailable:
            return false
        case .notMovieScreenshot, .movieTitleNotFound, .directorNotFound,
             .confidenceTooLow, .invalidExtractionResult:
            return true
        }
    }
}

// MARK: - Book Extraction Errors

/// Errors from AI-powered book metadata extraction.
enum BookExtractionError: Error, RecoverableError {
    /// The screenshot does not appear to be from a book app.
    case notBookScreenshot

    /// Could not identify a book title in the screenshot.
    case bookTitleNotFound

    /// Could not identify an author name in the screenshot.
    case authorNotFound

    /// Extraction confidence is below the required threshold.
    case confidenceTooLow(score: Float, threshold: Float)

    /// The AI model is not available on this device.
    case modelUnavailable

    /// The extraction result contained placeholder or invalid data.
    case invalidExtractionResult(reason: String)

    var errorDescription: String? {
        switch self {
        case .notBookScreenshot:
            return "This does not appear to be a book screenshot."
        case .bookTitleNotFound:
            return "Could not identify the book title."
        case .authorNotFound:
            return "Could not identify the author."
        case .confidenceTooLow(let score, let threshold):
            let scorePercent = Int(score * 100)
            let thresholdPercent = Int(threshold * 100)
            return "Extraction confidence (\(scorePercent)%) is below the \(thresholdPercent)% threshold."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .invalidExtractionResult(let reason):
            return "Invalid extraction result: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notBookScreenshot:
            return "Only screenshots from book apps (Kindle, Apple Books, Goodreads, etc.) are supported."
        case .bookTitleNotFound, .authorNotFound:
            return "Try a screenshot where the book title and author are clearly visible."
        case .confidenceTooLow:
            return "Try a clearer screenshot with the book title prominently displayed."
        case .modelUnavailable:
            return "This feature requires an iPhone 15 Pro or newer with iOS 18.1+."
        case .invalidExtractionResult:
            return "Try again with a different screenshot."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .modelUnavailable:
            return false
        case .notBookScreenshot, .bookTitleNotFound, .authorNotFound,
             .confidenceTooLow, .invalidExtractionResult:
            return true
        }
    }
}

// MARK: - TMDb Errors

/// Errors from TMDb API operations.
enum TMDbError: Error, RecoverableError {
    /// TMDb API key is not configured.
    case notConfigured

    /// Movie search failed.
    case searchFailed(reason: String)

    /// No movies found matching the search query.
    case noResultsFound(query: String)

    /// Network connectivity issue.
    case networkError(reason: String)

    /// API returned an unexpected response.
    case invalidResponse(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "TMDb API is not configured."
        case .searchFailed(let reason):
            return "TMDb search failed: \(reason)"
        case .noResultsFound(let query):
            return "No TMDb results for: \(query)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidResponse(let statusCode, let message):
            let detail = message ?? "Unknown error"
            return "TMDb API error (\(statusCode)): \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "TMDb integration is optional. Movie will still be logged to Google Docs."
        case .searchFailed, .networkError:
            return "Check your internet connection and try again."
        case .noResultsFound:
            return "The movie may not be in TMDb database."
        case .invalidResponse:
            return "Please try again. If the problem persists, TMDb may be experiencing issues."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notConfigured:
            return false
        case .searchFailed, .noResultsFound, .networkError, .invalidResponse:
            return true
        }
    }
}

// MARK: - Google Books Errors

/// Errors from Google Books API operations.
enum GoogleBooksError: Error, RecoverableError {
    /// User is not authenticated with Google Books.
    case notAuthenticated

    /// OAuth token has expired and needs refresh.
    case tokenExpired

    /// Book search failed.
    case searchFailed(reason: String)

    /// No books found matching the search query.
    case noResultsFound(query: String)

    /// Network connectivity issue.
    case networkError(reason: String)

    /// API returned an unexpected response.
    case invalidResponse(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Google Books access not connected."
        case .tokenExpired:
            return "Google session has expired."
        case .searchFailed(let reason):
            return "Google Books search failed: \(reason)"
        case .noResultsFound(let query):
            return "No Google Books results for: \(query)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidResponse(let statusCode, let message):
            let detail = message ?? "Unknown error"
            return "Google Books API error (\(statusCode)): \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Sign out and sign back in to grant Google Books access."
        case .tokenExpired:
            return "Please sign in again to refresh your session."
        case .searchFailed, .networkError:
            return "Check your internet connection and try again."
        case .noResultsFound:
            return "The book may not be in Google Books database."
        case .invalidResponse:
            return "Please try again. If the problem persists, contact support."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notAuthenticated:
            return false
        case .tokenExpired:
            return true
        case .searchFailed, .noResultsFound, .networkError, .invalidResponse:
            return true
        }
    }
}

// MARK: - YouTube Errors

/// Errors from YouTube Data API operations.
enum YouTubeError: Error, RecoverableError {
    /// User is not authenticated with YouTube.
    case notAuthenticated

    /// OAuth token has expired and needs refresh.
    case tokenExpired

    /// Video search failed.
    case searchFailed(reason: String)

    /// No videos found matching the search query.
    case noResultsFound(query: String)

    /// Failed to add video to playlist.
    case playlistOperationFailed(operation: String, reason: String)

    /// YouTube API daily quota has been exceeded.
    case quotaExceeded

    /// Network connectivity issue.
    case networkError(reason: String)

    /// API returned an unexpected response.
    case invalidResponse(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "YouTube account not connected."
        case .tokenExpired:
            return "YouTube session has expired."
        case .searchFailed(let reason):
            return "YouTube search failed: \(reason)"
        case .noResultsFound(let query):
            return "No YouTube results for: \(query)"
        case .playlistOperationFailed(let operation, let reason):
            return "Playlist \(operation) failed: \(reason)"
        case .quotaExceeded:
            return "YouTube API daily limit reached."
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidResponse(let statusCode, let message):
            let detail = message ?? "Unknown error"
            return "YouTube API error (\(statusCode)): \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Tap 'Sign in with YouTube' to connect your account."
        case .tokenExpired:
            return "Please sign in again to refresh your session."
        case .searchFailed:
            return "Check your internet connection and try again."
        case .noResultsFound:
            return "The song may not be available on YouTube, or try different search terms."
        case .playlistOperationFailed:
            return "Check that you have permission to modify this playlist."
        case .quotaExceeded:
            return "The daily API limit resets at midnight Pacific Time. Try again tomorrow."
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidResponse:
            return "Please try again. If the problem persists, contact support."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notAuthenticated, .quotaExceeded:
            return false
        case .tokenExpired:
            return true  // Can retry after re-auth
        case .searchFailed, .noResultsFound, .playlistOperationFailed,
             .networkError, .invalidResponse:
            return true
        }
    }
}

// Backward compatibility aliases
extension YouTubeError {
    /// Alias for backward compatibility.
    static func playlistInsertFailed(_ reason: String) -> YouTubeError {
        .playlistOperationFailed(operation: "insert", reason: reason)
    }
}

// MARK: - Keychain Errors

/// Errors from Keychain operations for secure storage.
enum KeychainError: Error, RecoverableError {
    /// Failed to save data to Keychain.
    case saveFailed(status: OSStatus)

    /// Failed to load data from Keychain.
    case loadFailed(status: OSStatus)

    /// Failed to delete data from Keychain.
    case deleteFailed(status: OSStatus)

    /// Stored data could not be decoded.
    case dataCorrupted

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save secure data (error \(status))."
        case .loadFailed(let status):
            return "Failed to load secure data (error \(status))."
        case .deleteFailed(let status):
            return "Failed to delete secure data (error \(status))."
        case .dataCorrupted:
            return "Secure storage data is corrupted."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .loadFailed, .deleteFailed:
            return "Try signing out and signing in again."
        case .dataCorrupted:
            return "Sign out to clear corrupted data, then sign in again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .saveFailed, .loadFailed, .deleteFailed:
            return true
        case .dataCorrupted:
            return false  // Needs manual intervention
        }
    }
}
