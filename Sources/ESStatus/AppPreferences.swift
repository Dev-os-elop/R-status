import AppKit
import Foundation

extension NSAppearance {
    var esIsDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var esPanelColor: NSColor {
        esIsDark
            ? NSColor(calibratedWhite: 0.14, alpha: 0.88)
            : NSColor(calibratedWhite: 0.90, alpha: 0.70)
    }

    var esTileColor: NSColor {
        esIsDark
            ? NSColor(calibratedWhite: 0.22, alpha: 0.88)
            : NSColor.controlBackgroundColor.withAlphaComponent(0.70)
    }
}

enum AppLanguage: String, CaseIterable {
    case system
    case korean
    case english

    var displayName: String {
        switch self {
        case .system: return L10n.text("시스템 언어", "System Language")
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    var usesKorean: Bool {
        switch self {
        case .korean: return true
        case .english: return false
        case .system:
            return Locale.preferredLanguages.first?.lowercased().hasPrefix("ko") == true
        }
    }
}

enum StatusIconStyle: String, CaseIterable {
    case catOutline
    case catSilhouette
    case statusPulse
    case progressBlocks
    case signalOrbit
    case windowCheck
    case layeredS

    var displayName: String {
        switch self {
        case .catOutline: return "Style 1"
        case .catSilhouette: return "Style 2"
        case .statusPulse: return "Style 3"
        case .progressBlocks: return "Style 4"
        case .signalOrbit: return "Style 5"
        case .windowCheck: return "Style 6"
        case .layeredS: return "Style 7"
        }
    }
}

enum AppPreferences {
    private static let languageKey = "appLanguage"
    private static let iconStyleKey = "statusIconStyle"
    static let elapsedTimeKey = "showElapsedTimeInMenuBar"
    private static let notificationsKey = "macOSNotificationsEnabled"
    private static let darkModeKey = "darkModeEnabled"
    private static let legacyDefaults = [
        "io.github.ljwook92.rstatus.cat",
        "io.github.ljwook92.rstatus"
    ].compactMap(UserDefaults.init(suiteName:))

    private static func migratedObject(forKey key: String) -> Any? {
        if let value = UserDefaults.standard.object(forKey: key) {
            return value
        }
        for defaults in legacyDefaults {
            if let value = defaults.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
                return value
            }
        }
        return nil
    }

    static var language: AppLanguage {
        get {
            guard let rawValue = migratedObject(forKey: languageKey) as? String,
                  let value = AppLanguage(rawValue: rawValue) else { return .system }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: languageKey) }
    }

    static var iconStyle: StatusIconStyle {
        get {
            guard let rawValue = migratedObject(forKey: iconStyleKey) as? String,
                  let value = StatusIconStyle(rawValue: rawValue) else { return .catOutline }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: iconStyleKey) }
    }

    static var showElapsedTime: Bool {
        get {
            guard let value = migratedObject(forKey: elapsedTimeKey) as? NSNumber else { return true }
            return value.boolValue
        }
        set { UserDefaults.standard.set(newValue, forKey: elapsedTimeKey) }
    }

    static var notificationsEnabled: Bool {
        get {
            guard let value = migratedObject(forKey: notificationsKey) as? NSNumber else { return true }
            return value.boolValue
        }
        set { UserDefaults.standard.set(newValue, forKey: notificationsKey) }
    }

    static var darkModeEnabled: Bool {
        get {
            guard let value = migratedObject(forKey: darkModeKey) as? NSNumber else { return false }
            return value.boolValue
        }
        set { UserDefaults.standard.set(newValue, forKey: darkModeKey) }
    }
}

enum L10n {
    static var korean: Bool { AppPreferences.language.usesKorean }

    static func text(_ koreanText: String, _ englishText: String) -> String {
        korean ? koreanText : englishText
    }
}
