import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    private func channel(_ value: Double) -> UInt32 {
        UInt32((min(max(value, 0), 1) * 255).rounded())
    }
}

extension CorbieRGB {
    static func solid(_ hex: String) -> Color {
        CorbieRGB(hex: hex)?.color ?? .clear
    }

    static func dynamic(light: String, dark: String) -> Color {
        guard let lightValue = CorbieRGB(hex: light), let darkValue = CorbieRGB(hex: dark) else {
            return .clear
        }
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkValue.platformColor : lightValue.platformColor
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkValue.platformColor : lightValue.platformColor
        })
        #else
        return lightValue.color
        #endif
    }

    #if canImport(UIKit)
    var platformColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }
    #elseif canImport(AppKit)
    var platformColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }
    #endif
}

enum CorbieHex {
    static let darkBackground = "#0B0E13"
    static let darkSurface = "#141A22"
    static let darkElevated = "#1C242E"
    static let darkBorder = "#252E3A"
    static let darkText = "#E6EDF5"
    static let darkTextSecondary = "#7D8A9B"

    static let lightBackground = "#F4F7FA"
    static let lightSurface = "#FFFFFF"
    static let lightElevated = "#FFFFFF"
    static let lightBorder = "#DBE3EC"
    static let lightText = "#0B0E13"
    static let lightTextSecondary = "#5A6878"

    static let ice = "#8FC5E8"
    static let warn = "#E8956F"
    static let accentInk = "#0B0E13"
    static let chromeStart = "#8FC5E8"
    static let chromeEnd = "#C4CDD6"

    static let partnerIce = "#6FB1E3"
    static let partnerFrostViolet = "#A98FE0"
    static let partnerGlacierTeal = "#58AFAB"
    static let partnerSteelBlue = "#7E9BC4"
    static let partnerSlate = "#8A97A8"
    static let partnerMint = "#6DB79B"
}

public enum MemberColorKey: String, CaseIterable, Codable, Identifiable, Sendable {
    case p1
    case p2
    case p3
    case p4
    case p5
    case p6

    public static let defaultA = MemberColorKey.p1
    public static let defaultB = MemberColorKey.p2

    public var id: String { rawValue }

    public var color: Color { CorbieRGB.solid(hex) }

    var hex: String {
        switch self {
        case .p1: return CorbieHex.partnerIce
        case .p2: return CorbieHex.partnerFrostViolet
        case .p3: return CorbieHex.partnerGlacierTeal
        case .p4: return CorbieHex.partnerSteelBlue
        case .p5: return CorbieHex.partnerSlate
        case .p6: return CorbieHex.partnerMint
        }
    }
}

public struct MemberColor: Equatable, Sendable {
    public let key: MemberColorKey

    public init(key: MemberColorKey) {
        self.key = key
    }

    public init(key: String?) {
        self.key = MemberColorKey(rawValue: key ?? "") ?? .defaultA
    }

    public var color: Color { key.color }
}

public enum CorbieColorPalette {
    public static let bg = CorbieRGB.dynamic(light: CorbieHex.lightBackground, dark: CorbieHex.darkBackground)
    public static let surface = CorbieRGB.dynamic(light: CorbieHex.lightSurface, dark: CorbieHex.darkSurface)
    public static let elevated = CorbieRGB.dynamic(light: CorbieHex.lightElevated, dark: CorbieHex.darkElevated)
    public static let border = CorbieRGB.dynamic(light: CorbieHex.lightBorder, dark: CorbieHex.darkBorder)
    public static let text = CorbieRGB.dynamic(light: CorbieHex.lightText, dark: CorbieHex.darkText)
    public static let text2 = CorbieRGB.dynamic(light: CorbieHex.lightTextSecondary, dark: CorbieHex.darkTextSecondary)

    public static let ice = CorbieRGB.solid(CorbieHex.ice)
    public static let warn = CorbieRGB.solid(CorbieHex.warn)
    public static let accentInk = CorbieRGB.solid(CorbieHex.accentInk)
    public static let chromeStart = CorbieRGB.solid(CorbieHex.chromeStart)
    public static let chromeEnd = CorbieRGB.solid(CorbieHex.chromeEnd)

    public static let partnerPalette = MemberColorKey.allCases

    public static var chrome: LinearGradient {
        LinearGradient(
            colors: [chromeStart, chromeEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public typealias CorbieColor = CorbieColorPalette

public extension Color {
    static var corbie: CorbieColorPalette.Type { CorbieColorPalette.self }
}
