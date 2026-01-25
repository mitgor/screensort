//
//  GoogleDocsService.swift
//  ScreenSort
//
//  Created by Claude on 2026-01-25.
//

import Foundation

/// Error types for Google Docs operations
enum GoogleDocsError: LocalizedError, RecoverableError {
    case notAuthenticated
    case documentNotFound
    case createFailed(reason: String)
    case updateFailed(reason: String)
    case networkError(reason: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google"
        case .documentNotFound:
            return "ScreenSort log document not found"
        case .createFailed(let reason):
            return "Failed to create document: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update document: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to Google"
        case .documentNotFound:
            return "The app will create a new document"
        default:
            return "Please try again"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        default:
            return false
        }
    }
}

/// Service for logging recognized content to a Google Doc
class GoogleDocsService: GoogleDocsServiceProtocol {

    private let authService: AuthServiceProtocol
    private let apiClient: APIClient

    private let docsBaseURL = "https://docs.googleapis.com/v1/documents"
    private let driveBaseURL = "https://www.googleapis.com/drive/v3/files"

    private let documentTitle = "ScreenSort - Recognized Content"

    /// Cached document ID
    private var cachedDocumentId: String?

    /// In-memory cache of entries for deduplication
    private var entriesCache: Set<String> = []

    var documentURL: String? {
        guard let docId = cachedDocumentId else { return nil }
        return "https://docs.google.com/document/d/\(docId)/edit"
    }

    init(
        authService: AuthServiceProtocol = AuthService(),
        apiClient: APIClient = APIClient.shared
    ) {
        self.authService = authService
        self.apiClient = apiClient
    }

    // MARK: - Public API

    func appendEntry(_ entry: ContentLogEntry) async throws -> Bool {
        // Check for duplicate
        let entryKey = "\(entry.type.rawValue):\(entry.title.lowercased()):\(entry.creator.lowercased())"
        if entriesCache.contains(entryKey) {
            return false  // Duplicate
        }

        let accessToken = try await authService.getValidAccessToken()
        let documentId = try await getOrCreateDocument(accessToken: accessToken)

        // Find the section for this content type and append
        try await appendToSection(
            documentId: documentId,
            section: entry.type.rawValue,
            text: entry.displayText,
            accessToken: accessToken
        )

        // Cache the entry
        entriesCache.insert(entryKey)

        return true
    }

    func getExistingEntries() async throws -> [ContentLogEntry] {
        // For now, return empty - full implementation would parse the document
        // The in-memory cache handles deduplication within a session
        return []
    }

    // MARK: - Document Management

    private func getOrCreateDocument(accessToken: String) async throws -> String {
        // Return cached ID if available
        if let docId = cachedDocumentId {
            return docId
        }

        // Search for existing document
        if let existingId = try await findExistingDocument(accessToken: accessToken) {
            cachedDocumentId = existingId
            try await loadExistingEntries(documentId: existingId, accessToken: accessToken)
            return existingId
        }

        // Create new document
        let newId = try await createDocument(accessToken: accessToken)
        cachedDocumentId = newId
        return newId
    }

    private func findExistingDocument(accessToken: String) async throws -> String? {
        let query = "name='\(documentTitle)' and mimeType='application/vnd.google-apps.document' and trashed=false"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        var components = URLComponents(string: driveBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name)")
        ]

        let (data, response) = try await apiClient.get(
            url: components.url!,
            headers: ["Authorization": "Bearer \(accessToken)"],
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        guard (200...299).contains(response.statusCode) else {
            throw GoogleDocsError.networkError(reason: "HTTP \(response.statusCode)")
        }

        let searchResult = try JSONDecoder().decode(DriveSearchResponse.self, from: data)
        return searchResult.files.first?.id
    }

    private func createDocument(accessToken: String) async throws -> String {
        let url = URL(string: docsBaseURL)!

        let body: [String: Any] = [
            "title": documentTitle
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await apiClient.post(
            url: url,
            body: bodyData,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        guard (200...299).contains(response.statusCode) else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GoogleDocsError.createFailed(reason: error)
        }

        let createResult = try JSONDecoder().decode(DocumentResponse.self, from: data)
        let documentId = createResult.documentId

        // Initialize document with section headers
        try await initializeDocumentSections(documentId: documentId, accessToken: accessToken)

        return documentId
    }

    private func initializeDocumentSections(documentId: String, accessToken: String) async throws {
        let url = URL(string: "\(docsBaseURL)/\(documentId):batchUpdate")!

        // Create initial content with all section headers
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        var insertIndex = 1
        var requests: [[String: Any]] = []

        // Title
        let header = "ScreenSort - Recognized Content\n\nAutomatically captured from screenshots\nLast updated: \(dateFormatter.string(from: Date()))\n\n"
        requests.append([
            "insertText": [
                "location": ["index": insertIndex],
                "text": header
            ]
        ])
        insertIndex += header.count

        // Section headers for each content type
        for contentType in ContentLogEntry.ContentType.allCases {
            let sectionHeader = "--- \(contentType.rawValue) ---\n\n"
            requests.append([
                "insertText": [
                    "location": ["index": insertIndex],
                    "text": sectionHeader
                ]
            ])
            insertIndex += sectionHeader.count
        }

        let body: [String: Any] = ["requests": requests]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await apiClient.post(
            url: url,
            body: bodyData,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        guard (200...299).contains(response.statusCode) else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GoogleDocsError.updateFailed(reason: error)
        }
    }

    private func appendToSection(
        documentId: String,
        section: String,
        text: String,
        accessToken: String
    ) async throws {
        // First, get the document to find the section location
        let getURL = URL(string: "\(docsBaseURL)/\(documentId)")!

        let (docData, docResponse) = try await apiClient.get(
            url: getURL,
            headers: ["Authorization": "Bearer \(accessToken)"],
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        guard (200...299).contains(docResponse.statusCode) else {
            throw GoogleDocsError.networkError(reason: "HTTP \(docResponse.statusCode)")
        }

        let document = try JSONDecoder().decode(DocumentContent.self, from: docData)

        // Find the section header and insert after it
        let sectionMarker = "--- \(section) ---"
        guard let insertIndex = findSectionInsertIndex(in: document, sectionMarker: sectionMarker) else {
            throw GoogleDocsError.updateFailed(reason: "Section not found: \(section)")
        }

        // Insert the new entry
        let url = URL(string: "\(docsBaseURL)/\(documentId):batchUpdate")!

        let entryText = "\(text)\n"
        let body: [String: Any] = [
            "requests": [
                [
                    "insertText": [
                        "location": ["index": insertIndex],
                        "text": entryText
                    ]
                ]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await apiClient.post(
            url: url,
            body: bodyData,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        guard (200...299).contains(response.statusCode) else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GoogleDocsError.updateFailed(reason: error)
        }
    }

    private func findSectionInsertIndex(in document: DocumentContent, sectionMarker: String) -> Int? {
        guard let body = document.body, let content = body.content else {
            return nil
        }

        for element in content {
            if let paragraph = element.paragraph,
               let elements = paragraph.elements {
                for textElement in elements {
                    if let textRun = textElement.textRun,
                       let text = textRun.content,
                       text.contains(sectionMarker) {
                        // Return index after the section header line
                        if let endIndex = textElement.endIndex {
                            return endIndex
                        }
                    }
                }
            }
        }

        return nil
    }

    private func loadExistingEntries(documentId: String, accessToken: String) async throws {
        // Load document content and parse existing entries for deduplication
        let getURL = URL(string: "\(docsBaseURL)/\(documentId)")!

        let (docData, docResponse) = try await apiClient.get(
            url: getURL,
            headers: ["Authorization": "Bearer \(accessToken)"],
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        guard (200...299).contains(docResponse.statusCode) else { return }

        let document = try JSONDecoder().decode(DocumentContent.self, from: docData)

        // Extract all text and build entries cache
        guard let body = document.body, let content = body.content else { return }

        var currentSection = ""
        for element in content {
            if let paragraph = element.paragraph,
               let elements = paragraph.elements {
                for textElement in elements {
                    if let textRun = textElement.textRun,
                       let text = textRun.content {
                        // Check if this is a section header
                        if text.contains("--- ") && text.contains(" ---") {
                            for contentType in ContentLogEntry.ContentType.allCases {
                                if text.contains(contentType.rawValue) {
                                    currentSection = contentType.rawValue
                                    break
                                }
                            }
                        } else if !currentSection.isEmpty && text.contains(" - ") {
                            // This looks like an entry
                            let key = "\(currentSection):\(text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
                            entriesCache.insert(key)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Response Models

private struct DriveSearchResponse: Decodable {
    let files: [DriveFile]

    struct DriveFile: Decodable {
        let id: String
        let name: String
    }
}

private struct DocumentResponse: Decodable {
    let documentId: String
}

private struct DocumentContent: Decodable {
    let documentId: String
    let body: DocumentBody?

    struct DocumentBody: Decodable {
        let content: [StructuralElement]?
    }

    struct StructuralElement: Decodable {
        let paragraph: Paragraph?
    }

    struct Paragraph: Decodable {
        let elements: [ParagraphElement]?
    }

    struct ParagraphElement: Decodable {
        let startIndex: Int?
        let endIndex: Int?
        let textRun: TextRun?
    }

    struct TextRun: Decodable {
        let content: String?
    }
}
