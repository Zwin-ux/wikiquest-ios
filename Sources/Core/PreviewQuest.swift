import Foundation

struct PreviewQuest: Equatable {
    let kicker: String
    let title: String
    let prompt: String
    let media: WikiMedia?
    let clues: [String]
    let choices: [PreviewQuestChoice]

    var correctChoice: PreviewQuestChoice? {
        choices.first { $0.isCorrect }
    }

    func choice(id: PreviewQuestChoice.ID) -> PreviewQuestChoice? {
        choices.first { $0.id == id }
    }

    static let firstRun = PreviewQuest(
        kicker: "FIRST RUN",
        title: "Guess the image.",
        prompt: "Reveal clues, make one call, then save your trail.",
        media: WikiMedia(
            thumbnailURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/The_Great_Wave_off_Kanagawa.jpg/640px-The_Great_Wave_off_Kanagawa.jpg"),
            imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/The_Great_Wave_off_Kanagawa.jpg/1024px-The_Great_Wave_off_Kanagawa.jpg"),
            sourceURL: URL(string: "https://en.wikipedia.org/wiki/The_Great_Wave_off_Kanagawa"),
            credit: "Wikipedia / Wikimedia Commons",
            license: "Public domain",
            fallbackStyle: .mystery
        ),
        clues: [
            "A wave towers over boats.",
            "The mountain in the distance is Fuji.",
            "It is a Japanese woodblock print by Hokusai."
        ],
        choices: [
            PreviewQuestChoice(id: "starry-night", title: "The Starry Night", detail: "Van Gogh painting", isCorrect: false),
            PreviewQuestChoice(id: "great-wave", title: "The Great Wave off Kanagawa", detail: "Hokusai print", isCorrect: true),
            PreviewQuestChoice(id: "mona-lisa", title: "Mona Lisa", detail: "Leonardo portrait", isCorrect: false)
        ]
    )
}

struct PreviewQuestChoice: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isCorrect: Bool
}

struct PreviewQuestSession: Equatable {
    private(set) var revealedClueCount: Int
    private(set) var selectedChoiceID: PreviewQuestChoice.ID?

    init(revealedClueCount: Int = 1, selectedChoiceID: PreviewQuestChoice.ID? = nil) {
        self.revealedClueCount = max(1, revealedClueCount)
        self.selectedChoiceID = selectedChoiceID
    }

    var hasSelection: Bool {
        selectedChoiceID != nil
    }

    func visibleClues(in quest: PreviewQuest) -> [String] {
        Array(quest.clues.prefix(min(revealedClueCount, quest.clues.count)))
    }

    func canRevealMore(in quest: PreviewQuest) -> Bool {
        !hasSelection && revealedClueCount < quest.clues.count
    }

    func result(in quest: PreviewQuest) -> PreviewQuestResult? {
        guard let selectedChoiceID, let choice = quest.choice(id: selectedChoiceID) else {
            return nil
        }
        if choice.isCorrect {
            return .correct(title: choice.title)
        }
        return .missed(selectedTitle: choice.title, correctTitle: quest.correctChoice?.title ?? "the article")
    }

    mutating func revealNext(in quest: PreviewQuest) {
        guard canRevealMore(in: quest) else { return }
        revealedClueCount = min(revealedClueCount + 1, quest.clues.count)
    }

    mutating func choose(choiceID: PreviewQuestChoice.ID, in quest: PreviewQuest) {
        guard !hasSelection, quest.choice(id: choiceID) != nil else { return }
        selectedChoiceID = choiceID
    }
}

enum PreviewQuestResult: Equatable {
    case correct(title: String)
    case missed(selectedTitle: String, correctTitle: String)
}
