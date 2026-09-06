import Foundation

public extension Calendar {
    func daysAway(from now: Date, to date: Date) -> Int? {
        dateComponents([.day], from: startOfDay(for: now), to: startOfDay(for: date)).day
    }
}
