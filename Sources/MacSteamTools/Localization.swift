import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case id = "id"   // Bahasa Indonesia
    case en = "en"   // English

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .id: return "Indonesia"
        case .en: return "English"
        }
    }
}

// MARK: - String Keys

enum L10nKey {
    // App
    case appName, appVersion

    // Sidebar
    case workspaceSection
    case navGames, navDashboard, navSettings
    case bottleActive, setupRequired
    case noBottleSelected
    case openInSettings
    case openSteam

    // Header
    case headerGames, headerDashboard, headerSettings
    case subGames, subDashboard, subSettings

    // Games Page
    case searchPlaceholder
    case searchButton
    case searchingLabel
    case chooseBottleInfo
    case openSettings
    case searchResultsLabel
    case gamesCount
    case luaPathHint
    case emptySubtitleNotSearched, emptySubtitleSearched
    case emptyBodyNotSearched, emptyBodySearched
    case luaInstalled
    case updateLua, downloadLua

    // Dashboard Page
    case dashboardEmpty, dashboardEmptyBody
    case installedLuaSection, installedLuaCount
    case uninstallLuaButton
    case confirmUninstallLuaTitle, confirmUninstallLuaBody
    case confirmUninstallAllTitle, confirmUninstallAllBody
    case uninstallAllButton

    // Danger Zone (Settings)
    case dangerZoneTitle, dangerZoneSubtitle, dangerZoneUninstallDesc

    // Settings Page
    case crossOverCardTitle, crossOverCardSubtitle
    case pickBottle, rescanBottle, chooseFolder
    case steamLabel, steamNotFound
    case changeButton, pickButton
    case crossOverLocation
    case crossOverAppLabel

    case modulesCardTitle, modulesCardSubtitle
    case latestRelease, lastInstalled
    case versionCheckedAtInstall, notYetInstalled
    case checkVersionButton
    case autoBackupLabel
    case installModulesButton, updateModulesButton
    case modulesSource

    case librariesCardTitle, librariesCardSubtitle
    case librariesTarget
    case checkLibrariesButton
    case openWinecfgButton
    case notChecked

    case openSteamFolder, viewBackup

    // Confirmations
    case confirmTitle
    case confirmBottle
    case confirmModulesBody
    case confirmLuaBody
    case confirmFooter
    case cancelButton, proceedButton

    // Footer / Status
    case detailButton

    // Status messages (dynamic – use fmt below)
    case statusDefault
    case statusSearchEmpty
    case statusCheckRelease
    case statusDownloading
    case statusInstalling
    case statusModulesDone
    case statusLuaDone
    case statusLibrariesOk
    case statusLibrariesBad
    case statusReadingLibraries
    case statusLaunched
    case statusWinecfgOpened
}

// MARK: - Localization Engine

final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: AppLanguage = .id {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            loadTranslations()
        }
    }

    private var strings: [String: String] = [:]

    init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        }
        loadTranslations()
    }

    private func loadTranslations() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Language/\(language.rawValue)") else {
            print("Translation file not found for \(language.rawValue)")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            strings = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Failed to load translations: \(error)")
        }
    }

    func str(_ key: L10nKey) -> String {
        strings[String(describing: key)] ?? "⚠️\(key)"
    }

    /// Formatted string – uses `String(format:)`. Pass args in order.
    func fmt(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: str(key), arguments: args)
    }
}

// MARK: - Convenience global functions

/// Shorthand: `L(.openSteam)` → localized string
func L(_ key: L10nKey) -> String { Localization.shared.str(key) }

/// Formatted: `LF(.statusLuaDone, game.name, game.id)`
func LF(_ key: L10nKey, _ args: CVarArg...) -> String {
    String(format: Localization.shared.str(key), arguments: args)
}
