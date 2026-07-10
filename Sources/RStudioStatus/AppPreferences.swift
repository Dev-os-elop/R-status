import Foundation

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
        case .catOutline: return "Cat Original"
        case .catSilhouette: return "Cat Silhouette"
        case .statusPulse: return "Status Pulse"
        case .progressBlocks: return "Progress Blocks"
        case .signalOrbit: return "Signal Orbit"
        case .windowCheck: return "Window Check"
        case .layeredS: return "Layered S"
        }
    }
}

enum AppPreferences {
    private static let languageKey = "appLanguage"
    private static let iconStyleKey = "statusIconStyle"
    static let elapsedTimeKey = "showElapsedTimeInMenuBar"
    private static let legacyDefaults = UserDefaults(suiteName: "io.github.ljwook92.rstatus")

    private static func migratedObject(forKey key: String) -> Any? {
        if let value = UserDefaults.standard.object(forKey: key) {
            return value
        }
        guard let value = legacyDefaults?.object(forKey: key) else { return nil }
        UserDefaults.standard.set(value, forKey: key)
        return value
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
}

enum L10n {
    static var korean: Bool { AppPreferences.language.usesKorean }

    static func text(_ koreanText: String, _ englishText: String) -> String {
        korean ? koreanText : englishText
    }
}
