import Foundation
import SwiftUI
import Testing
@testable import CorbieCore

@Suite struct DesignPaletteTests {
    static let brandBook: [CorbieTheme: [String]] = [
        .ice: ["#F4F7FA", "#FFFFFF", "#FFFFFF", "#DBE3EC", "#0B0E13", "#5A6878", "#8FC5E8", "#8FC5E8", "#0B0E13", "#E8956F"],
        .sand: ["#FAF9F6", "#FFFFFF", "#F4F1EA", "#E6DAC8", "#3A322A", "#7A6857", "#8C7358", "#3A322A", "#FAF9F6", "#B5553C"],
        .sage: ["#F2F1E8", "#FBFAF4", "#E8E7DA", "#D4D0B9", "#2E3A28", "#5F6A53", "#394931", "#394931", "#F2F1E8", "#A85A3C"],
        .deep: ["#1E2025", "#29343D", "#35434E", "#3C5665", "#E4EAEE", "#92A4B1", "#7FB0CC", "#E4EAEE", "#1E2025", "#E8956F"]
    ]

    static let brandBookMembers: [CorbieTheme: [MemberColorSlot: String]] = [
        .ice: [.teal: "#489693", .blue: "#318FD7", .violet: "#9879DA", .rose: "#CE6A8D", .clay: "#B87C57", .green: "#4B977A"],
        .sand: [.teal: "#47939E", .blue: "#454D80", .violet: "#A676B2", .rose: "#B8637C", .clay: "#94653B", .green: "#3E6B3C"],
        .sage: [.teal: "#458E99", .blue: "#424A7A", .violet: "#A276AD", .rose: "#B2647C", .clay: "#8F6036", .green: "#396637"],
        .deep: [.teal: "#46A8B8", .blue: "#6174F2", .violet: "#CC91DB", .rose: "#FA91B0", .clay: "#C7854C", .green: "#529E4F"]
    ]

    private func tokens(_ palette: ThemePalette) -> [Color] {
        [
            palette.bg, palette.surface, palette.elevated, palette.border, palette.text,
            palette.text2, palette.accent, palette.ctaFill, palette.ctaText, palette.warn
        ]
    }

    @Test func everyTokenMatchesTheBrandBook() {
        for theme in CorbieTheme.allCases {
            guard let expected = Self.brandBook[theme] else { continue }
            #expect(expected.count == tokens(theme.palette).count)
            for (token, hex) in zip(tokens(theme.palette), expected) {
                #expect(token == Color(hex: hex), "\(theme.rawValue) token \(hex)")
            }
        }
    }

    @Test func everyMemberSlotMatchesTheBrandBook() {
        for theme in CorbieTheme.allCases {
            guard let expected = Self.brandBookMembers[theme] else { continue }
            #expect(theme.palette.memberColors.count == MemberColorSlot.allCases.count)
            for slot in MemberColorSlot.allCases {
                #expect(theme.palette.member(slot) == Color(hex: expected[slot] ?? ""), "\(theme.rawValue) \(slot.rawValue)")
            }
        }
    }

    @Test func onlyDeepIsDark() {
        #expect(CorbieTheme.deep.isDark)
        #expect(CorbieTheme.ice.isDark == false)
        #expect(CorbieTheme.sand.isDark == false)
        #expect(CorbieTheme.sage.isDark == false)
    }

    @Test func everyMemberColourClearsTheBrandBookFloorOnLightThemes() {
        for theme in CorbieTheme.allCases where theme.isDark == false {
            guard let members = Self.brandBookMembers[theme], let tokens = Self.brandBook[theme] else { continue }
            let background = tokens[0]
            for slot in MemberColorSlot.allCases {
                guard let hex = members[slot] else { continue }
                let ratio = Self.contrast(hex, background)
                #expect(ratio >= 3.2, "\(theme.rawValue) \(slot.rawValue) is \(ratio)")
            }
        }
    }

    static func contrast(_ lhs: String, _ rhs: String) -> Double {
        let high = max(relativeLuminance(lhs), relativeLuminance(rhs))
        let low = min(relativeLuminance(lhs), relativeLuminance(rhs))
        return (high + 0.05) / (low + 0.05)
    }

    static func relativeLuminance(_ hex: String) -> Double {
        guard let channels = CorbieRGB(hex: hex) else { return 0 }
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(channels.red) + 0.7152 * linear(channels.green) + 0.0722 * linear(channels.blue)
    }

    @Test func hexParsingAcceptsLowercaseAndMissingHash() {
        #expect(CorbieRGB(hex: "8fc5e8") == CorbieRGB(hex: "#8FC5E8"))
    }

    @Test func hexParsingRejectsMalformedInput() {
        #expect(CorbieRGB(hex: "") == nil)
        #expect(CorbieRGB(hex: "#8FC5E") == nil)
        #expect(CorbieRGB(hex: "#8FC5E8F") == nil)
        #expect(CorbieRGB(hex: "#GGGGGG") == nil)
        #expect(CorbieRGB(hex: "+12345") == nil)
    }

    @Test func brandHexesRoundTrip() {
        for hexes in Self.brandBook.values {
            for hex in hexes {
                #expect(CorbieRGB(hex: hex)?.hexString == hex)
            }
        }
    }
}

extension Color {
    fileprivate init(hex: String) {
        guard let channels = CorbieRGB(hex: hex) else {
            self = .clear
            return
        }
        self = Color(.sRGB, red: channels.red, green: channels.green, blue: channels.blue, opacity: 1)
    }
}
