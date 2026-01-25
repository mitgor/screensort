import Foundation

protocol AuthServiceProtocol {
    /// Check if user is authenticated (has valid or refreshable tokens)
    var isAuthenticated: Bool { get }

    /// Get valid access token (refreshes if needed)
    func getValidAccessToken() async throws -> String

    /// Start OAuth authentication flow
    func authenticate() async throws

    /// Sign out and clear tokens
    func signOut() throws
}
