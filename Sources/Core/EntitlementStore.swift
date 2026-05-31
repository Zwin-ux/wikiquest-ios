import Foundation

@MainActor
final class EntitlementStore: ObservableObject {
    @Published var summary: EntitlementSummary?
    @Published var isLoading = false
    @Published var error: String?

    var isMember: Bool {
        summary?.isMember == true
    }

    func refresh(api: WikiQuestAPIClient, signedIn: Bool) async {
        guard signedIn else {
            summary = nil
            error = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await api.entitlements()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
