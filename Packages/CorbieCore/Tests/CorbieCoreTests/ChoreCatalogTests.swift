import Foundation
import Testing
@testable import CorbieCore

@Suite struct ChoreCatalogTests {
    private let catalog = ChoreCatalog.bundled

    @Test func theBundledCatalogLoadsFromTheModuleBundle() {
        #expect(ChoreCatalog.bundledURL != nil)
        #expect(catalog.items.count == 44)
        #expect(catalog.isEmpty == false)
    }

    @Test func everyGroupFromTheSpecIsCovered() {
        let counts = Dictionary(grouping: catalog.items, by: \.group).mapValues(\.count)
        #expect(counts[.kitchen] == 7)
        #expect(counts[.cleaning] == 7)
        #expect(counts[.laundry] == 4)
        #expect(counts[.shopping] == 3)
        #expect(counts[.money] == 5)
        #expect(counts[.pets] == 4)
        #expect(counts[.plants] == 1)
        #expect(counts[.car] == 3)
        #expect(counts[.outside] == 3)
        #expect(counts[.keepingInTouch] == 7)
        #expect(catalog.groups.count == ChoreGroup.allCases.count)
    }

    @Test func everyItemHasAUniqueIdAndFiveLanguages() {
        #expect(Set(catalog.items.map(\.id)).count == catalog.items.count)
        for item in catalog.items {
            #expect(item.id.hasPrefix("c"))
            for language in ChoreCatalogItem.languages {
                let text = item.text[language] ?? ""
                #expect(text.isEmpty == false, "\(item.id) has no \(language) text")
                #expect(text.contains("!") == false, "\(item.id) [\(language)] shouts")
                #expect(text.contains("\u{2014}") == false, "\(item.id) [\(language)] uses an em dash")
                #expect(text.count <= 44, "\(item.id) [\(language)] is too long for a chip")
            }
            #expect(item.text.count == ChoreCatalogItem.languages.count)
        }
    }

    @Test func aChipTextFollowsTheLocaleAndFallsBackToEnglish() throws {
        let item = try #require(catalog.item(id: "c001"))
        #expect(item.text(for: Locale(identifier: "en_GB")) == "Wash the dishes")
        #expect(item.text(for: Locale(identifier: "de_DE")) == "Geschirr spülen")
        #expect(item.text(for: Locale(identifier: "pl_PL")) == "Wash the dishes")
    }

    @Test func theStarterListIsSmallEnoughToRateAndBigEnoughToSplit() {
        let preselected = catalog.preselectedIds
        #expect(preselected.count >= ChoreSetDTO.minimumIncludedItems)
        #expect(preselected.count <= 20)
        #expect(Set(preselected).count == preselected.count)
        for id in preselected {
            #expect(catalog.item(id: id) != nil)
        }
    }

    @Test func howOftenAChoreComesUpDrivesItsWeeklyLoad() {
        #expect(ChoreFrequency.daily.loadPerWeek == 7)
        #expect(ChoreFrequency.fewTimesAWeek.loadPerWeek == 3)
        #expect(ChoreFrequency.weekly.loadPerWeek == 1)
        #expect(ChoreFrequency.everyTwoWeeks.loadPerWeek == 0.5)
        #expect(ChoreFrequency.monthly.loadPerWeek == 0.25)
        #expect(ChoreFrequency.quarterly.loadPerWeek == 0.1)
        for item in catalog.items {
            #expect(item.loadPerWeek == item.frequency.loadPerWeek)
        }
    }

    @Test func aChoreFrequencyBecomesATaskRecurrence() {
        #expect(ChoreFrequency.daily.recurrence == .daily)
        #expect(ChoreFrequency.fewTimesAWeek.recurrence == .weekdays([2, 4, 6]))
        #expect(ChoreFrequency.weekly.recurrence == .weekly)
        #expect(ChoreFrequency.everyTwoWeeks.recurrence == .everyTwoWeeks)
        #expect(ChoreFrequency.monthly.recurrence == .monthly)
        #expect(ChoreFrequency.quarterly.recurrence == .quarterly)
    }

    @Test func aMissingFileLeavesAnEmptyCatalog() {
        let catalog = ChoreCatalog.load(from: URL(fileURLWithPath: "/nowhere/Chores.json"))
        #expect(catalog.isEmpty)
        #expect(catalog.preselectedIds.isEmpty)
        #expect(catalog.groups.isEmpty)
    }
}
