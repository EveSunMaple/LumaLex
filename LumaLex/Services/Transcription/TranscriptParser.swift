import Foundation

struct ParsedSubtitle: Equatable {
    let start: TimeInterval
    let end: TimeInterval
    let english: String
    let chinese: String
}

enum TranscriptParser {
    static func parse(_ text: String) -> [ParsedSubtitle] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
        return normalized.components(separatedBy: "\n\n").compactMap { block in
            let lines = block.split(separator: "\n").map(String.init)
            guard let timeIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
            let parts = lines[timeIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = timestamp(parts[0]), let end = timestamp(parts[1]),
                  start >= 0, end > start else { return nil }
            let content = lines.dropFirst(timeIndex + 1).map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("NOTE") }
            let english = content.filter { !$0.contains(where: isHan) }.joined(separator: " ")
            let chinese = content.filter { $0.contains(where: isHan) }.joined(separator: " ")
            guard !english.isEmpty || !chinese.isEmpty else { return nil }
            return ParsedSubtitle(start: start, end: end, english: english, chinese: chinese)
        }
        .sorted { $0.start < $1.start }
    }

    static func activeIndex(at time: TimeInterval, in subtitles: [ParsedSubtitle]) -> Int? {
        var low = 0
        var high = subtitles.count
        while low < high {
            let mid = (low + high) / 2
            if subtitles[mid].start <= time { low = mid + 1 } else { high = mid }
        }
        let index = low - 1
        guard index >= 0, time < subtitles[index].end else { return nil }
        return index
    }

    private static func timestamp(_ raw: String) -> TimeInterval? {
        let value = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").first
            .map(String.init)?.replacingOccurrences(of: ",", with: ".") ?? ""
        let parts = value.split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              let seconds = Double(parts.last ?? ""), seconds < 60,
              let minutes = Double(parts[parts.count - 2]), minutes < 60 else { return nil }
        let hours = parts.count == 3 ? Double(parts[0]) : 0
        guard let hours, hours >= 0, minutes >= 0, seconds >= 0 else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    private static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
}

