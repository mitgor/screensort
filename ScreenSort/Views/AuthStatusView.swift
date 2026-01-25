import SwiftUI

struct AuthStatusView: View {
    let isAuthenticated: Bool
    let onLogin: () async -> Void
    let onLogout: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isAuthenticated ? .green : .orange)

            Text(isAuthenticated ? "YouTube Connected" : "YouTube Not Connected")
                .font(.subheadline)

            Spacer()

            if isAuthenticated {
                Button("Sign Out") {
                    onLogout()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Button("Connect") {
                    Task {
                        await onLogin()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
