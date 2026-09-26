import SwiftUI

// MARK: - Page enum

enum Page: String, CaseIterable {
    case dashboard = "navDashboard"
    case games = "navGames"
    case settings = "navSettings"

    var localizedName: String {
        switch self {
        case .games:     return L(.navGames)
        case .dashboard: return L(.navDashboard)
        case .settings:  return L(.navSettings)
        }
    }
    var icon: String {
        switch self {
        case .games:     return "gamecontroller"
        case .dashboard: return "square.grid.2x2"
        case .settings:  return "gearshape"
        }
    }
}

// MARK: - InstallAction

enum InstallAction: Identifiable {
    case modules, lua(Game)
    var id: String {
        switch self {
        case .modules:        return "modules"
        case .lua(let game):  return game.id
        }
    }
}

// MARK: - UninstallAction

enum UninstallAction: Identifiable {
    case lua(String)   // appID
    case all
    var id: String {
        switch self {
        case .lua(let id): return "lua-\(id)"
        case .all:         return "uninstall-all"
        }
    }
}

// MARK: - Design tokens

struct AppTheme {
    static let accent  = Color(red: 0.57, green: 0.52, blue: 1)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let bg      = Color(red: 0.065, green: 0.073, blue: 0.10)
    static let sidebar = Color(red: 0.085, green: 0.093, blue: 0.125)
}
