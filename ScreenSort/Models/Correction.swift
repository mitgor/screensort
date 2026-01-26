import Foundation

/// Reason why user made this correction
enum CorrectionReason: String, Codable, CaseIterable {
    case wrongCategory = "wrong_category"
    case wrongTitle = "wrong_title"
    case wrongCreator = "wrong_creator"
    case wrongBoth = "wrong_both"
    case missedContent = "missed_content"
    case other = "other"

    var displayName: String {
        switch self {
        case .wrongCategory:
            return "Wrong category"
        case .wrongTitle:
            return "Wrong title"
        case .wrongCreator:
            return "Wrong artist/director/author"
        case .wrongBoth:
            return "Wrong title and creator"
        case .missedContent:
            return "Missed the content"
        case .other:
            return "Other"
        }
    }
}

/// Stores a user's correction for a misclassified screenshot
struct Correction: Codable, Identifiable, Sendable {
    let id: UUID
    let assetId: String
    let createdAt: Date

    // Original classification
    let originalType: ScreenshotType
    let originalTitle: String?
    let originalCreator: String?

    // User's correction
    let correctedType: ScreenshotType
    let correctedTitle: String?
    let correctedCreator: String?

    // For learning
    let ocrTextSnapshot: [String]
    let correctionReason: CorrectionReason?

    /// Whether the correction has been applied to the photo library
    var isApplied: Bool

    init(
        id: UUID = UUID(),
        assetId: String,
        createdAt: Date = Date(),
        originalType: ScreenshotType,
        originalTitle: String?,
        originalCreator: String?,
        correctedType: ScreenshotType,
        correctedTitle: String?,
        correctedCreator: String?,
        ocrTextSnapshot: [String],
        correctionReason: CorrectionReason?,
        isApplied: Bool = false
    ) {
        self.id = id
        self.assetId = assetId
        self.createdAt = createdAt
        self.originalType = originalType
        self.originalTitle = originalTitle
        self.originalCreator = originalCreator
        self.correctedType = correctedType
        self.correctedTitle = correctedTitle
        self.correctedCreator = correctedCreator
        self.ocrTextSnapshot = ocrTextSnapshot
        self.correctionReason = correctionReason
        self.isApplied = isApplied
    }

    /// Whether the category was changed (not just metadata)
    var categoryChanged: Bool {
        originalType != correctedType
    }

    /// Display title for the correction
    var displayTitle: String {
        correctedTitle ?? originalTitle ?? "Unknown"
    }

    /// Display creator for the correction
    var displayCreator: String? {
        correctedCreator ?? originalCreator
    }
}

// MARK: - ScreenshotType Codable Conformance

extension ScreenshotType: Codable {}
