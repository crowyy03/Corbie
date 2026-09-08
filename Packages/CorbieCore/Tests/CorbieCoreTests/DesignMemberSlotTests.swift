import Foundation
import Testing
@testable import CorbieCore

@Suite struct DesignMemberSlotTests {
    @Test func thePairsForbiddenEverywhereAreForbiddenInEveryTheme() {
        let forbidden: [(MemberColorSlot, MemberColorSlot)] = [
            (.teal, .blue), (.blue, .green), (.violet, .rose), (.rose, .clay)
        ]
        for theme in CorbieTheme.allCases {
            for pair in forbidden {
                #expect(pair.0.conflicts(with: pair.1, in: theme))
                #expect(pair.1.conflicts(with: pair.0, in: theme))
            }
        }
    }

    @Test func tealAndGreenOnlyClashInDeep() {
        #expect(MemberColorSlot.teal.conflicts(with: .green, in: .deep))
        #expect(MemberColorSlot.teal.conflicts(with: .green, in: .sand) == false)
        #expect(MemberColorSlot.teal.conflicts(with: .green, in: .sage) == false)
    }

    @Test func theSameSlotAlwaysConflicts() {
        for slot in MemberColorSlot.allCases {
            for theme in CorbieTheme.allCases {
                #expect(slot.conflicts(with: slot, in: theme))
            }
        }
    }

    @Test func theDefaultPairIsAllowedInEveryTheme() {
        for theme in CorbieTheme.allCases {
            #expect(MemberColorSlot.creatorDefault.conflicts(with: .partnerDefault, in: theme) == false)
        }
    }

    @Test func everySlotHasAFreeSlotToShiftTo() {
        for theme in CorbieTheme.allCases {
            for wanted in MemberColorSlot.allCases {
                for taken in MemberColorSlot.allCases {
                    let free = wanted.nearestFreeSlot(against: taken, in: theme)
                    #expect(free.conflicts(with: taken, in: theme) == false, "\(theme) \(wanted) vs \(taken)")
                }
            }
        }
    }

    @Test func aFreeSlotIsLeftAlone() {
        #expect(MemberColorSlot.teal.nearestFreeSlot(against: .rose, in: .deep) == .teal)
    }

    @Test func aClashShiftsToTheNextFreeSlotInOrder() {
        #expect(MemberColorSlot.teal.nearestFreeSlot(against: .teal, in: .sand) == .violet)
        #expect(MemberColorSlot.blue.nearestFreeSlot(against: .teal, in: .sand) == .violet)
        #expect(MemberColorSlot.violet.nearestFreeSlot(against: .rose, in: .sand) == .green)
    }

    @Test func theOldKeysMapToTheNewSlots() {
        #expect(MemberColorSlot.stored("p1") == .teal)
        #expect(MemberColorSlot.stored("p2") == .rose)
        #expect(MemberColorSlot.stored("p3") == .blue)
        #expect(MemberColorSlot.stored("p4") == .violet)
        #expect(MemberColorSlot.stored("p5") == .clay)
        #expect(MemberColorSlot.stored("p6") == .green)
    }

    @Test func slotNamesRoundTripAndUnknownFallsBack() {
        for slot in MemberColorSlot.allCases {
            #expect(MemberColorSlot.stored(slot.rawValue) == slot)
        }
        #expect(MemberColorSlot.stored("fog") == .creatorDefault)
        #expect(MemberColorSlot.stored(nil) == .creatorDefault)
        #expect(MemberColorSlot.stored("") == .creatorDefault)
    }
}
