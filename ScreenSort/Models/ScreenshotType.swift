import Foundation

/// Categories for screenshot classification
enum ScreenshotType: String, CaseIterable, Codable {
    case music
    case movie
    case book
    case meme
    case unknown

    /// Destination album name for processed screenshots of this type
    var albumName: String {
        switch self {
        case .music:
            return "ScreenSort - Music"
        case .movie:
            return "ScreenSort - Movies"
        case .book:
            return "ScreenSort - Books"
        case .meme:
            return "ScreenSort - Memes"
        case .unknown:
            return "ScreenSort - Flagged"
        }
    }

    /// Whether this type requires AI extraction of metadata
    var requiresExtraction: Bool {
        switch self {
        case .music, .movie, .book:
            return true
        case .meme, .unknown:
            return false
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .music:
            return "Music"
        case .movie:
            return "Movie"
        case .book:
            return "Book"
        case .meme:
            return "Meme"
        case .unknown:
            return "Unknown"
        }
    }

    /// SF Symbol name for this content type
    var iconName: String {
        switch self {
        case .music:
            return "music.note"
        case .movie:
            return "film"
        case .book:
            return "book"
        case .meme:
            return "face.smiling"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
