import Foundation

struct ReviewState: Equatable {
    let stage: Int
    let nextReviewDate: Date
    let status: VocabularyStatus
}

enum ReviewScheduler {
    static func initial(at date: Date, calendar: Calendar = .current) -> ReviewState {
        ReviewState(stage: 0, nextReviewDate: calendar.startOfDay(for: date), status: .learning)
    }

    static func isDue(_ state: ReviewState, at date: Date, calendar: Calendar = .current) -> Bool {
        state.status == .learning &&
            calendar.startOfDay(for: date) >= calendar.startOfDay(for: state.nextReviewDate)
    }

    static func transition(from state: ReviewState, result: ReviewResult, at date: Date,
                           calendar: Calendar = .current) -> ReviewState {
        let day = calendar.startOfDay(for: date)
        guard result == .remembered else {
            return ReviewState(stage: 0, nextReviewDate: day, status: .learning)
        }

        let stage = min(state.stage + 1, 4)
        guard stage < 4 else {
            return ReviewState(stage: 4, nextReviewDate: day, status: .learned)
        }
        let days = [0, 2, 5, 10][stage]
        let nextDate = calendar.date(byAdding: .day, value: days, to: day) ?? day
        return ReviewState(stage: stage, nextReviewDate: nextDate, status: .learning)
    }
}

