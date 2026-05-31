import Foundation

struct ClipQuest: Codable, Equatable {
    let kicker: String
    let title: String
    let prompt: String
    let imageURL: URL?
    let sourceURL: URL?
    let clues: [String]
    let choices: [ClipQuestChoice]

    var correctChoice: ClipQuestChoice? {
        choices.first { $0.isCorrect }
    }

    func choice(id: ClipQuestChoice.ID) -> ClipQuestChoice? {
        choices.first { $0.id == id }
    }

    static let wikipedia = ClipQuest(
        kicker: "APP CLIP",
        title: "30-second Mystery.",
        prompt: "Read the image and clues, then make one guess.",
        imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/The_Great_Wave_off_Kanagawa.jpg/640px-The_Great_Wave_off_Kanagawa.jpg"),
        sourceURL: URL(string: "https://en.wikipedia.org/wiki/The_Great_Wave_off_Kanagawa"),
        clues: [
            "A wave towers over boats.",
            "The mountain in the distance is Fuji.",
            "It is a Japanese woodblock print by Hokusai."
        ],
        choices: [
            ClipQuestChoice(id: "starry-night", title: "The Starry Night", detail: "Van Gogh painting", isCorrect: false),
            ClipQuestChoice(id: "great-wave", title: "The Great Wave off Kanagawa", detail: "Hokusai print", isCorrect: true),
            ClipQuestChoice(id: "mona-lisa", title: "Mona Lisa", detail: "Leonardo portrait", isCorrect: false)
        ]
    )
}

struct ClipQuestChoice: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isCorrect: Bool
}

struct ClipQuestSession: Equatable {
    private(set) var revealedClueCount: Int
    private(set) var selectedChoiceID: ClipQuestChoice.ID?

    init(revealedClueCount: Int = 1, selectedChoiceID: ClipQuestChoice.ID? = nil) {
        self.revealedClueCount = max(0, revealedClueCount)
        self.selectedChoiceID = selectedChoiceID
    }

    var hasSelection: Bool {
        selectedChoiceID != nil
    }

    func visibleClues(in quest: ClipQuest) -> [String] {
        Array(quest.clues.prefix(min(revealedClueCount, quest.clues.count)))
    }

    func canRevealMore(in quest: ClipQuest) -> Bool {
        !hasSelection && revealedClueCount < quest.clues.count
    }

    func result(in quest: ClipQuest) -> ClipQuestResult? {
        guard let selectedChoiceID, let choice = quest.choice(id: selectedChoiceID) else {
            return nil
        }
        if choice.isCorrect {
            return .correct(title: choice.title, xpPreview: 120)
        }
        return .missed(
            selectedTitle: choice.title,
            correctTitle: quest.correctChoice?.title ?? "the hidden page"
        )
    }

    mutating func revealNext(in quest: ClipQuest) {
        guard canRevealMore(in: quest) else { return }
        revealedClueCount = min(revealedClueCount + 1, quest.clues.count)
    }

    mutating func choose(choiceID: ClipQuestChoice.ID, in quest: ClipQuest) {
        guard !hasSelection, quest.choice(id: choiceID) != nil else { return }
        selectedChoiceID = choiceID
        revealedClueCount = max(revealedClueCount, 1)
    }

    mutating func reset() {
        revealedClueCount = 1
        selectedChoiceID = nil
    }
}

enum ClipQuestResult: Equatable {
    case correct(title: String, xpPreview: Int)
    case missed(selectedTitle: String, correctTitle: String)
}
