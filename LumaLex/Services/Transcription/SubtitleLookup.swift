import Foundation

enum SubtitleLookup {
    static func activeIndex(at time: TimeInterval, in segments: [SubtitleSegment]) -> Int? {
        var low = 0
        var high = segments.count
        while low < high {
            let mid = (low + high) / 2
            if segments[mid].startTime <= time { low = mid + 1 } else { high = mid }
        }
        let index = low - 1
        guard index >= 0, time < segments[index].endTime else { return nil }
        return index
    }
}

