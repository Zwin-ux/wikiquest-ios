import Foundation

struct DailyDeckVisualState: Equatable {
    let title: String
    let detail: String
    let media: WikiMedia?
    let visualState: ArticleVisualState
    let stateLabel: String
    let stateSystemImage: String

    static func make(from daily: DailyRandomState?) -> DailyDeckVisualState {
        guard let daily else {
            return DailyDeckVisualState(
                title: "Daily Mystery",
                detail: "Load today's hidden page.",
                media: nil,
                visualState: .locked,
                stateLabel: "Locked",
                stateSystemImage: "lock.fill"
            )
        }

        let thumbnailMedia = DailyDeckVisualState.thumbnailMedia(from: daily)
        let title = DailyDeckVisualState.title(from: daily)

        if daily.isComplete {
            return DailyDeckVisualState(
                title: title,
                detail: daily.isCorrect ? "Solved for \(daily.score) XP." : "Answer revealed.",
                media: thumbnailMedia,
                visualState: .revealed,
                stateLabel: daily.isCorrect ? "Solved" : "Revealed",
                stateSystemImage: daily.isCorrect ? "checkmark.seal.fill" : "eye.fill"
            )
        }

        if thumbnailMedia != nil {
            return DailyDeckVisualState(
                title: title,
                detail: "Photo clue open. Finish the hidden page.",
                media: thumbnailMedia,
                visualState: .clue,
                stateLabel: "Clue",
                stateSystemImage: "camera.aperture"
            )
        }

        return DailyDeckVisualState(
            title: title,
            detail: "Reveal a hint to unlock the image.",
            media: nil,
            visualState: .locked,
            stateLabel: "Locked",
            stateSystemImage: "lock.fill"
        )
    }

    private static func title(from daily: DailyRandomState) -> String {
        if daily.isComplete, let answer = daily.answer?.title {
            return answer
        }
        return "Daily Mystery #\(daily.puzzleNumber)"
    }

    private static func thumbnailMedia(from daily: DailyRandomState) -> WikiMedia? {
        guard
            let thumbnail = daily.revealedHints.first(where: { $0.type.lowercased() == "thumbnail" }),
            case .string(let value) = thumbnail.value
        else {
            return nil
        }

        return WikiMedia.from(
            thumbnail: value,
            image: value,
            source: daily.isComplete ? daily.answer?.pageUrl : nil,
            fallbackStyle: .mystery
        )
    }
}
