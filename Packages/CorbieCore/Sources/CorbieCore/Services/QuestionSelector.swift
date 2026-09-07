import Foundation

public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public struct QuestionSelection: Sendable, Equatable {
    public let questionId: String
    public let nextIndex: Int

    public init(questionId: String, nextIndex: Int) {
        self.questionId = questionId
        self.nextIndex = nextIndex
    }
}

public enum QuestionSelector {
    public static func seed(forSpaceId spaceId: UUID) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in Array(spaceId.uuidString.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }

    public static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func order(_ questionIds: [String], seed: UInt64) -> [String] {
        var shuffled = questionIds
        guard shuffled.count > 1 else { return shuffled }
        var generator = SeededGenerator(seed: seed)
        for position in stride(from: shuffled.count - 1, to: 0, by: -1) {
            let pick = Int(generator.next() % UInt64(position + 1))
            shuffled.swapAt(position, pick)
        }
        return shuffled
    }

    public static func selection(
        bank: QuestionBank,
        seed: UInt64,
        index: Int,
        togetherSince: Date?,
        now: Date,
        calendar: Calendar = .utc
    ) -> QuestionSelection? {
        let ordered = order(bank.questionIds, seed: seed)
        guard ordered.isEmpty == false else { return nil }
        let start = index < 0 ? 0 : index % ordered.count
        for offset in 0..<ordered.count {
            let position = (start + offset) % ordered.count
            let questionId = ordered[position]
            guard let entry = bank.entry(id: questionId),
                  entry.stage.suits(togetherSince: togetherSince, now: now, calendar: calendar) else { continue }
            return QuestionSelection(questionId: questionId, nextIndex: (position + 1) % ordered.count)
        }
        return nil
    }
}
