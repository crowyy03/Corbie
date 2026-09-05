import Foundation

struct InviteCountdown: Equatable {
    let remaining: TimeInterval

    init(expiresAt: Date, now: Date) {
        remaining = max(0, expiresAt.timeIntervalSince(now))
    }

    var isExpired: Bool { remaining <= 0 }

    func text(locale: Locale = .current) -> String {
        Duration.seconds(Int(remaining.rounded(.up)))
            .formatted(.time(pattern: .minuteSecond).locale(locale))
    }
}
