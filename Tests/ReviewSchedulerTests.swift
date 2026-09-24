import Foundation
import XCTest
@testable import LumaLex

final class ReviewSchedulerTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12,
                      calendar: Calendar? = nil) -> Date {
        (calendar ?? utc).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testNewWordIsDueOnCreationDay() {
        let created = date(2026, 9, 24)
        let state = ReviewScheduler.initial(at: created, calendar: utc)
        XCTAssertEqual(state.stage, 0)
        XCTAssertEqual(state.status, .learning)
        XCTAssertTrue(ReviewScheduler.isDue(state, at: created, calendar: utc))
        XCTAssertFalse(ReviewScheduler.isDue(state, at: date(2026, 9, 23), calendar: utc))
    }

    func testSuccessfulReviewsUseOffsetsFromEachSuccess() {
        var state = ReviewScheduler.initial(at: date(2026, 9, 24), calendar: utc)
        state = ReviewScheduler.transition(from: state, result: .remembered,
                                           at: date(2026, 9, 24), calendar: utc)
        XCTAssertEqual(state.stage, 1)
        XCTAssertEqual(state.nextReviewDate, date(2026, 9, 26, hour: 0))
        state = ReviewScheduler.transition(from: state, result: .remembered,
                                           at: date(2026, 9, 28), calendar: utc)
        XCTAssertEqual(state.stage, 2)
        XCTAssertEqual(state.nextReviewDate, date(2026, 10, 3, hour: 0))
        state = ReviewScheduler.transition(from: state, result: .remembered,
                                           at: date(2026, 10, 3), calendar: utc)
        XCTAssertEqual(state.stage, 3)
        XCTAssertEqual(state.nextReviewDate, date(2026, 10, 13, hour: 0))
    }

    func testForgotResetsToStageZeroAndIsDueToday() {
        let previous = ReviewState(stage: 3, nextReviewDate: date(2026, 10, 13), status: .learning)
        let now = date(2026, 10, 13)
        let state = ReviewScheduler.transition(from: previous, result: .forgot, at: now, calendar: utc)
        XCTAssertEqual(state.stage, 0)
        XCTAssertEqual(state.status, .learning)
        XCTAssertTrue(ReviewScheduler.isDue(state, at: now, calendar: utc))
    }

    func testFourthSuccessMovesWordToLearned() {
        var state = ReviewScheduler.initial(at: date(2026, 9, 24), calendar: utc)
        for day in [24, 26] {
            state = ReviewScheduler.transition(from: state, result: .remembered,
                                               at: date(2026, 9, day), calendar: utc)
        }
        state = ReviewScheduler.transition(from: state, result: .remembered,
                                           at: date(2026, 10, 1), calendar: utc)
        state = ReviewScheduler.transition(from: state, result: .remembered,
                                           at: date(2026, 10, 11), calendar: utc)
        XCTAssertEqual(state.stage, 4)
        XCTAssertEqual(state.status, .learned)
        XCTAssertFalse(ReviewScheduler.isDue(state, at: date(2026, 10, 20), calendar: utc))
    }

    func testCalendarDayAdditionCrossesDaylightSavingBoundary() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let beforeChange = date(2026, 10, 31, calendar: newYork)
        let initial = ReviewScheduler.initial(at: beforeChange, calendar: newYork)
        let next = ReviewScheduler.transition(from: initial, result: .remembered,
                                              at: beforeChange, calendar: newYork)
        XCTAssertEqual(next.nextReviewDate, date(2026, 11, 2, hour: 0, calendar: newYork))
        XCTAssertTrue(ReviewScheduler.isDue(next, at: date(2026, 11, 2, calendar: newYork),
                                            calendar: newYork))
    }

    func testDueDateUsesCurrentTimeZoneCalendarDay() {
        let due = date(2026, 9, 25, hour: 0)
        let state = ReviewState(stage: 1, nextReviewDate: due, status: .learning)
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        XCTAssertTrue(ReviewScheduler.isDue(state, at: date(2026, 9, 24, hour: 20),
                                            calendar: shanghai))
    }
}

