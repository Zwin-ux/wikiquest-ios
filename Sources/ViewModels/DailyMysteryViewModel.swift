import Foundation

enum MysteryMode: String, CaseIterable, Identifiable, Equatable {
    case daily = "Daily"
    case practice = "Practice"

    var id: String { rawValue }
}

@MainActor
final class DailyMysteryViewModel: ObservableObject {
    @Published var mode: MysteryMode = .daily
    @Published var daily: DailyRandomState?
    @Published var practice: PracticeState?
    @Published var guess = ""
    @Published var suggestions: [String] = []
    @Published var error: String?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var answerArticle: WikiArticle?

    private let api: WikiQuestAPIClient
    private let wikipedia: WikipediaClient

    init(api: WikiQuestAPIClient, wikipedia: WikipediaClient = WikipediaClient()) {
        self.api = api
        self.wikipedia = wikipedia
    }

    var currentHints: [WikiHint] {
        mode == .daily ? daily?.revealedHints ?? [] : practice?.revealedHints ?? []
    }

    var title: String {
        if mode == .daily, let number = daily?.puzzleNumber {
            return "#\(number)"
        }
        if mode == .practice {
            return practice?.puzzleId ?? "Practice"
        }
        return "Loading"
    }

    var hintsRevealed: Int {
        mode == .daily ? daily?.hintsRevealed ?? 0 : practice?.hintsRevealed ?? 0
    }

    var totalHints: Int {
        mode == .daily ? daily?.totalHints ?? 6 : practice?.totalHints ?? 6
    }

    var maxGuesses: Int {
        mode == .daily ? daily?.maxGuesses ?? 6 : practice?.maxGuesses ?? 6
    }

    var guessesUsed: Int {
        mode == .daily ? daily?.guessCount ?? 0 : practice?.guessesUsed ?? 0
    }

    var guessesRemaining: Int {
        mode == .daily ? daily?.guessesRemaining ?? max(0, maxGuesses - guessesUsed) : max(0, maxGuesses - guessesUsed)
    }

    var progress: Double {
        guard totalHints > 0 else { return 0 }
        return min(1, Double(hintsRevealed) / Double(totalHints))
    }

    var isComplete: Bool {
        mode == .daily ? daily?.isComplete == true : practice?.isComplete == true
    }

    var isCorrect: Bool {
        mode == .daily ? daily?.isCorrect == true : practice?.isCorrect == true
    }

    var score: Int {
        mode == .daily ? daily?.score ?? 0 : practice?.score ?? 0
    }

    var timeMs: Int {
        mode == .daily ? daily?.timeMs ?? 0 : 0
    }

    var answerTitle: String? {
        mode == .daily ? daily?.answer?.title : practice?.answer?.title
    }

    var clueMedia: WikiMedia? {
        guard let thumbnail = currentHints.first(where: { $0.type.lowercased() == "thumbnail" }) else {
            return nil
        }
        guard case .string(let value) = thumbnail.value else {
            return nil
        }
        return WikiMedia.from(
            thumbnail: value,
            image: value,
            source: answerPageURL?.absoluteString,
            fallbackStyle: .mystery
        )
    }

    var mysteryMedia: WikiMedia? {
        if isComplete {
            return answerArticle?.media ?? clueMedia
        }
        return clueMedia
    }

    var photoVisualState: ArticleVisualState {
        if isComplete {
            return .revealed
        }
        return clueMedia == nil ? .locked : .clue
    }

    var photoTitle: String {
        isComplete ? answerTitle ?? "Mystery solved" : "Hidden article"
    }

    var guessHistory: [GuessRecord] {
        daily?.guesses ?? []
    }

    private var answerPageURL: URL? {
        let page = mode == .daily ? daily?.answer?.pageUrl : practice?.answer?.pageUrl
        return page.flatMap(URL.init(string:))
    }

    func setMode(_ nextMode: MysteryMode, signedIn: Bool) async {
        guard mode != nextMode else { return }
        mode = nextMode
        guess = ""
        suggestions = []
        answerArticle = nil
        await load(signedIn: signedIn)
    }

    func load(signedIn: Bool) async {
        guard signedIn else {
            error = "Sign in with Apple to save Mystery XP and streaks."
            daily = nil
            practice = nil
            suggestions = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            error = nil
            if mode == .daily {
                daily = try await api.dailyMystery()
            } else {
                practice = try await api.practiceMystery()
            }
            await loadAnswerMediaIfNeeded()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func revealHint(signedIn: Bool) async {
        guard signedIn else {
            error = "Sign in with Apple to reveal hints."
            return
        }
        guard !isSubmitting, !isComplete else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if mode == .daily {
                daily = try await api.revealDailyHint()
            } else if let id = practice?.puzzleId {
                practice = try await api.revealPracticeHint(puzzleId: id)
            }
            await loadAnswerMediaIfNeeded()
            Haptics.light()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func submitGuess(signedIn: Bool, forcedGuess: String? = nil) async {
        guard signedIn else {
            error = "Sign in with Apple to submit guesses."
            return
        }
        let value = (forcedGuess ?? guess).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !isSubmitting, !isComplete else { return }
        let wasComplete = isComplete
        guess = ""
        suggestions = []
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if mode == .daily {
                daily = try await api.submitDailyGuess(value)
            } else if let id = practice?.puzzleId {
                practice = try await api.submitPracticeGuess(puzzleId: id, guess: value)
            }
            await loadAnswerMediaIfNeeded()
            if isComplete && !wasComplete {
                if isCorrect {
                    Haptics.success()
                } else {
                    Haptics.error()
                }
            } else {
                Haptics.light()
            }
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func refreshSuggestions() async {
        let value = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2, !isComplete else {
            suggestions = []
            return
        }
        do {
            suggestions = try await wikipedia.searchTitles(prefix: value)
        } catch {
            suggestions = []
        }
    }

    private func loadAnswerMediaIfNeeded() async {
        guard isComplete, let title = answerTitle else { return }
        if answerArticle?.title == title { return }
        answerArticle = try? await wikipedia.summary(title: title)
    }
}
