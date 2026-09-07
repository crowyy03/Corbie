import Foundation
import SwiftUI

public enum CorbieTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case sand
    case sage
    case deep

    public static let lightChoices: [CorbieTheme] = [.sand, .sage]
    public static let darkChoices: [CorbieTheme] = [.deep]

    public var id: String { rawValue }

    public var displayNameKey: String { "theme.name." + rawValue }

    public var isDark: Bool { self == .deep }

    public var palette: ThemePalette {
        switch self {
        case .sand: return ThemePalette.sand
        case .sage: return ThemePalette.sage
        case .deep: return ThemePalette.deep
        }
    }
}

public enum MemberColorSlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case teal
    case blue
    case violet
    case rose
    case clay
    case green

    public static let creatorDefault = MemberColorSlot.teal
    public static let partnerDefault = MemberColorSlot.rose

    public var id: String { rawValue }

    public var displayNameKey: String { "member.color." + rawValue }

    public func conflicts(with other: MemberColorSlot, in theme: CorbieTheme) -> Bool {
        let pair = Set([self, other])
        if pair.count == 1 { return true }
        if MemberColorSlot.forbiddenEverywhere.contains(pair) { return true }
        return theme == .deep && MemberColorSlot.forbiddenInDeep.contains(pair)
    }

    public func nearestFreeSlot(against taken: MemberColorSlot, in theme: CorbieTheme) -> MemberColorSlot {
        let all = MemberColorSlot.allCases
        guard let start = all.firstIndex(of: self) else { return self }
        for step in 0 ..< all.count {
            let candidate = all[(start + step) % all.count]
            if candidate.conflicts(with: taken, in: theme) == false { return candidate }
        }
        return self
    }

    private static let forbiddenEverywhere: Set<Set<MemberColorSlot>> = [
        [.teal, .blue],
        [.blue, .green],
        [.violet, .rose],
        [.rose, .clay]
    ]

    private static let forbiddenInDeep: Set<Set<MemberColorSlot>> = [[.teal, .green]]
}

extension MemberColorSlot {
    private static let legacyKeys: [String: MemberColorSlot] = [
        "p1": .teal,
        "p2": .rose,
        "p3": .blue,
        "p4": .violet,
        "p5": .clay,
        "p6": .green
    ]

    public static func stored(_ key: String?) -> MemberColorSlot {
        guard let key, key.isEmpty == false else { return .creatorDefault }
        if let slot = MemberColorSlot(rawValue: key) { return slot }
        return legacyKeys[key] ?? .creatorDefault
    }
}

public struct ThemePalette: Sendable, Equatable {
    public let bg: Color
    public let surface: Color
    public let elevated: Color
    public let border: Color
    public let text: Color
    public let text2: Color
    public let accent: Color
    public let ctaFill: Color
    public let ctaText: Color
    public let warn: Color
    public let memberColors: [MemberColorSlot: Color]

    public func member(_ slot: MemberColorSlot) -> Color {
        memberColors[slot] ?? text2
    }

    public func member(storedKey: String?) -> Color {
        member(MemberColorSlot.stored(storedKey))
    }
}

extension ThemePalette {
    static let sand = ThemePalette(
        bg: hex("#FAF9F6"),
        surface: hex("#FFFFFF"),
        elevated: hex("#F4F1EA"),
        border: hex("#E6DAC8"),
        text: hex("#3A322A"),
        text2: hex("#7A6857"),
        accent: hex("#8C7358"),
        ctaFill: hex("#3A322A"),
        ctaText: hex("#FAF9F6"),
        warn: hex("#B5553C"),
        memberColors: [
            .teal: hex("#47939E"),
            .blue: hex("#454D80"),
            .violet: hex("#A676B2"),
            .rose: hex("#B8637C"),
            .clay: hex("#94653B"),
            .green: hex("#3E6B3C")
        ]
    )

    static let sage = ThemePalette(
        bg: hex("#F2F1E8"),
        surface: hex("#FBFAF4"),
        elevated: hex("#E8E7DA"),
        border: hex("#D4D0B9"),
        text: hex("#2E3A28"),
        text2: hex("#5F6A53"),
        accent: hex("#394931"),
        ctaFill: hex("#394931"),
        ctaText: hex("#F2F1E8"),
        warn: hex("#A85A3C"),
        memberColors: [
            .teal: hex("#458E99"),
            .blue: hex("#424A7A"),
            .violet: hex("#A276AD"),
            .rose: hex("#B2647C"),
            .clay: hex("#8F6036"),
            .green: hex("#396637")
        ]
    )

    static let deep = ThemePalette(
        bg: hex("#1E2025"),
        surface: hex("#29343D"),
        elevated: hex("#35434E"),
        border: hex("#3C5665"),
        text: hex("#E4EAEE"),
        text2: hex("#92A4B1"),
        accent: hex("#7FB0CC"),
        ctaFill: hex("#E4EAEE"),
        ctaText: hex("#1E2025"),
        warn: hex("#E8956F"),
        memberColors: [
            .teal: hex("#46A8B8"),
            .blue: hex("#6174F2"),
            .violet: hex("#CC91DB"),
            .rose: hex("#FA91B0"),
            .clay: hex("#C7854C"),
            .green: hex("#529E4F")
        ]
    )

    private static func hex(_ value: String) -> Color {
        guard let channels = CorbieRGB(hex: value) else { return .clear }
        return Color(.sRGB, red: channels.red, green: channels.green, blue: channels.blue, opacity: 1)
    }
}

struct CorbieRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init?(hex: String) {
        var digits = Substring(hex)
        if digits.hasPrefix("#") {
            digits = digits.dropFirst()
        }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let packed = UInt32(digits, radix: 16) else {
            return nil
        }
        red = Double((packed >> 16) & 0xFF) / 255
        green = Double((packed >> 8) & 0xFF) / 255
        blue = Double(packed & 0xFF) / 255
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    private func channel(_ value: Double) -> UInt32 {
        UInt32((min(max(value, 0), 1) * 255).rounded())
    }
}
