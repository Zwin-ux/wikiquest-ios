import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var entitlements: EntitlementSummary?
    @Published var contributionLog: [ContributionLogEntry] = []
    @Published var discoveredItems: [QuestDeckItem] = []
    @Published var mysteryStats: MysteryStats?
    @Published var dailyLeaderboard: DailyLeaderboard?
    @Published var error: String?
    @Published var saveError: String?
    @Published var isLoading = false
    @Published var isEditing = false
    @Published var nameInput = ""
    @Published var bioInput = ""

    private let api: WikiQuestAPIClient
    private let wikipedia: WikipediaClient

    init(api: WikiQuestAPIClient, wikipedia: WikipediaClient = WikipediaClient()) {
        self.api = api
        self.wikipedia = wikipedia
    }

    var displayName: String {
        if let custom = profile?.customDisplayName, !custom.isEmpty {
            return custom
        }
        return profile?.displayName ?? "Explorer"
    }

    var isMember: Bool {
        entitlements?.isMember == true
    }

    func load(signedIn: Bool) async {
        guard signedIn else {
            profile = nil
            entitlements = nil
            contributionLog = []
            discoveredItems = []
            mysteryStats = nil
            dailyLeaderboard = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            async let profileTask = try api.userProfile()
            async let entitlementTask = try api.entitlements()
            async let logTask = try api.contributionLog()
            async let statsTask = try? api.mysteryStats()
            async let dailyTask = try? api.dailyLeaderboard()
            profile = try await profileTask
            entitlements = try await entitlementTask
            contributionLog = try await logTask
            mysteryStats = await statsTask
            dailyLeaderboard = await dailyTask
            await refreshDiscoveredItems()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openEditor() {
        guard isMember else {
            saveError = "Profile editing is a Member feature."
            Haptics.error()
            return
        }
        nameInput = profile?.customDisplayName ?? ""
        bioInput = profile?.bio ?? ""
        saveError = nil
        isEditing = true
        Haptics.light()
    }

    func saveEditor() async {
        guard isMember else { return }
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let bio = bioInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 40 else {
            saveError = "Display name must stay under 40 characters."
            return
        }
        guard bio.count <= 280 else {
            saveError = "Bio must stay under 280 characters."
            return
        }
        do {
            profile = try await api.updateProfile(
                displayName: name.isEmpty ? nil : name,
                bio: bio.isEmpty ? nil : bio
            )
            isEditing = false
            saveError = nil
            Haptics.success()
        } catch {
            saveError = error.localizedDescription
            Haptics.error()
        }
    }

    private func refreshDiscoveredItems() async {
        var seen = Set<String>()
        var items: [QuestDeckItem] = []
        for entry in contributionLog {
            guard !seen.contains(entry.articleTitle), items.count < 6 else { continue }
            seen.insert(entry.articleTitle)
            let article = try? await wikipedia.summary(title: entry.articleTitle)
            items.append(
                QuestDeckItem(
                    id: "\(entry.id)-\(entry.articleTitle)",
                    title: article?.title ?? entry.articleTitle,
                    detail: "\(entry.mode) / \(entry.xpEarned) XP",
                    media: article?.media,
                    tintName: "green"
                )
            )
        }
        discoveredItems = items
    }
}
