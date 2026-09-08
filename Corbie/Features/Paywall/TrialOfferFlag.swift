import CorbieCore
import Foundation

struct TrialOfferFlag {
    static let storageKey = "corbie.paywall.trialOfferShown"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    var hasBeenShown: Bool {
        defaults.bool(forKey: TrialOfferFlag.storageKey)
    }

    func claim() -> Bool {
        guard hasBeenShown == false else { return false }
        defaults.set(true, forKey: TrialOfferFlag.storageKey)
        return true
    }
}
