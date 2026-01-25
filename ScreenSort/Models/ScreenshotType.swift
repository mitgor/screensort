import Foundation

/// Categories for screenshot classification
enum ScreenshotType: String, CaseIterable {
    case music
    case movie
    case book
    case unknown

    /// Destination album name for processed screenshots of this type
    var albumName: String {
        switch self {
        case .music:
            return "ScreenSort - Processed"
        case .movie:
            return "ScreenSort - Processed"
        case .book:
            return "ScreenSort - Processed"
        case .unknown:
            return "ScreenSort - Flagged"
        }
    }
}
