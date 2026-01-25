import Foundation

protocol YouTubeServiceProtocol {
    /// Search YouTube for a song, returns video ID if found
    func searchForSong(title: String, artist: String) async throws -> String

    /// Add video to playlist
    func addToPlaylist(videoId: String, playlistId: String) async throws

    /// Get or create the ScreenSort playlist
    func getOrCreatePlaylist(named: String) async throws -> String
}
