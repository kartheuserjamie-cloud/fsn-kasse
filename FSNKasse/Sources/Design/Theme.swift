import SwiftUI
import UIKit

enum Theme {
    static let primary = Color(hex: 0x4A154B)
    static let primaryLight = Color(hex: 0x5A1F5B)
    static let accent = Color(hex: 0xF5A9B8)
    static let text = Color(hex: 0x111111)
    static let muted = Color(hex: 0x6B7280)
    static let border = Color(hex: 0xE0E0E0)
    static let borderStrong = Color(hex: 0xCCCCCC)
    static let surface = Color(hex: 0xF8F9FA)
    static let danger = Color(hex: 0xC62828)
    static let errorBackground = Color(hex: 0xF8D7DA)
    static let errorText = Color(hex: 0x721C24)
    static let successBackground = Color(hex: 0xD4EDDA)
    static let successText = Color(hex: 0x155724)

    static let flagBlue = Color(hex: 0x5BCEFA)
    static let flagPink = Color(hex: 0xF5A9B8)
    static let flagGrey = Color(hex: 0xE8E8E8)
    static let heroMagenta = Color(hex: 0xC8379B)
    static let heroPink = Color(hex: 0xF1A3D1)

    static let dotGreen = Color(hex: 0x22C55E)
    static let dotAmber = Color(hex: 0xF59E0B)
    static let dotRed = Color(hex: 0xEF4444)
    static let dotGrey = Color(hex: 0x9CA3AF)

    static let radius: CGFloat = 2
    static let cardRadius: CGFloat = 4

    /// Femboy flag as used in the website's top bar.
    static let flagColors: [Color] = [flagBlue, flagPink, flagGrey, flagPink, flagBlue]
    /// Seven stripes of the hero section on the website.
    static let heroColors: [Color] = [heroMagenta, heroPink, .white, flagBlue, .white, heroPink, heroMagenta]
    static let confettiColors: [Color] = [flagBlue, flagPink, .white, heroMagenta, heroPink]
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Arial, like the website.
    static func fsn(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Arial-BoldMT" : "ArialMT", size: size)
    }
}

@MainActor
enum Appearance {
    static func apply() {
        let titleFont = UIFont(name: "Arial-BoldMT", size: 17) ?? .boldSystemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "Arial-BoldMT", size: 30) ?? .boldSystemFont(ofSize: 30)
        let textColor = UIColor(hex: 0x111111)

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .white
        navigation.shadowColor = UIColor(hex: 0xE0E0E0)
        navigation.titleTextAttributes = [.font: titleFont, .foregroundColor: textColor]
        navigation.largeTitleTextAttributes = [.font: largeTitleFont, .foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x4A154B)

        let itemFont = UIFont(name: "ArialMT", size: 11) ?? .systemFont(ofSize: 11)
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = .white
        tabBar.shadowColor = UIColor(hex: 0xE0E0E0)
        for layout in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            layout.normal.titleTextAttributes = [.font: itemFont, .foregroundColor: UIColor(hex: 0x6B7280)]
            layout.normal.iconColor = UIColor(hex: 0x6B7280)
            layout.selected.titleTextAttributes = [.font: itemFont, .foregroundColor: UIColor(hex: 0x4A154B)]
            layout.selected.iconColor = UIColor(hex: 0x4A154B)
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }
}
