import SwiftUI
import Testing
@testable import CorbieCore

@Suite struct DesignColorTests {
    static let brandHexes = [
        "#0B0E13", "#141A22", "#1C242E", "#252E3A", "#E6EDF5", "#7D8A9B",
        "#F4F7FA", "#FFFFFF", "#DBE3EC", "#5A6878",
        "#8FC5E8", "#E8956F", "#C4CDD6",
        "#6FB1E3", "#A98FE0", "#58AFAB", "#7E9BC4", "#8A97A8", "#6DB79B"
    ]

    @Test func brandHexesRoundTrip() {
        for hex in Self.brandHexes {
            let parsed = CorbieRGB(hex: hex)
            #expect(parsed != nil)
            #expect(parsed?.hexString == hex)
        }
    }

    @Test func parsingAcceptsLowercaseAndMissingHash() {
        #expect(CorbieRGB(hex: "8fc5e8") == CorbieRGB(hex: "#8FC5E8"))
    }

    @Test func parsingRejectsMalformedInput() {
        #expect(CorbieRGB(hex: "") == nil)
        #expect(CorbieRGB(hex: "#8FC5E") == nil)
        #expect(CorbieRGB(hex: "#8FC5E8F") == nil)
        #expect(CorbieRGB(hex: "#GGGGGG") == nil)
        #expect(CorbieRGB(hex: "+12345") == nil)
    }

    @Test func channelsMapToUnitRange() {
        let white = CorbieRGB(hex: "#FFFFFF")
        #expect(white?.red == 1)
        #expect(white?.green == 1)
        #expect(white?.blue == 1)

        let black = CorbieRGB(hex: "#000000")
        #expect(black?.red == 0)
        #expect(black?.green == 0)
        #expect(black?.blue == 0)
    }

    @Test func partnerPaletteHasSixUniqueKeys() {
        let palette = CorbieColorPalette.partnerPalette
        #expect(palette.count == 6)
        #expect(Set(palette).count == 6)
        #expect(Set(palette.map(\.hex)).count == 6)
    }

    @Test func partnerDefaultsMatchBrandBook() {
        #expect(MemberColorKey.defaultA == .p1)
        #expect(MemberColorKey.defaultB == .p2)
        #expect(MemberColorKey.p1.hex == "#6FB1E3")
        #expect(MemberColorKey.p2.hex == "#A98FE0")
    }

    @Test func everyPartnerHexParses() {
        for key in MemberColorKey.allCases {
            #expect(CorbieRGB(hex: key.hex)?.hexString == key.hex)
        }
    }

    @Test func namespacedAccessResolvesToTheSameTokens() {
        #expect(Color.corbie.bg == CorbieColorPalette.bg)
        #expect(CorbieColor.ice == CorbieColorPalette.ice)
        #expect(Color.corbie.partnerPalette == MemberColorKey.allCases)
    }

    @Test func memberColorResolvesStoredKey() {
        #expect(MemberColor(key: "p4").key == .p4)
        #expect(MemberColor(key: "p9").key == MemberColorKey.defaultA)
        #expect(MemberColor(key: nil).key == MemberColorKey.defaultA)
    }
}
