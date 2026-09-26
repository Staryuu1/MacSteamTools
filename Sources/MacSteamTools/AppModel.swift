import Foundation
import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var bottles: [URL] = []
    @Published var prefix: URL?
    @Published var steam: URL?
    @Published var crossOverApp: URL
    @Published var query = ""
    @Published var games: [Game] = []
    @Published var searched = false
    @Published var searching = false
    @Published var busy = false
    @Published var status = L(.statusDefault)
    @Published var failed = false
    @Published var release: GitHubRelease?
    @Published var checkingRelease = false
    @Published var overrides: [String: String] = [:]
    @Published var installedLua: Set<String> = []
    var luaNames: [String: String] = [:]
    @Published var installedVersion: String?
    @Published var backup: URL?
    let catalog = Catalog()
    private let defaults = UserDefaults.standard

    init() {
        crossOverApp = URL(fileURLWithPath: UserDefaults.standard.string(forKey: "crossOverApp") ?? "/Applications/CrossOver.app")
        scan()
        if let path = defaults.string(forKey: "prefix") {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("system.reg").path) {
                let savedSteam = defaults.string(forKey: "steam")
                selectBottle(url)
                if let stored = savedSteam, FileManager.default.fileExists(atPath: stored + "/steam.exe") {
                    let candidate = URL(fileURLWithPath: stored)
                    if Installer.inside(candidate, url.appendingPathComponent("drive_c")) {
                        steam = candidate; defaults.set(stored, forKey: "steam")
                    }
                }
                refreshLocalState()
            }
        } else if bottles.count == 1 { selectBottle(bottles[0]) }
    }

    // MARK: - Computed

    var target: Target? {
        guard let prefix, let steam else { return nil }
        return Target(prefix: prefix, steam: steam, runtime: crossOverApp.appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine"))
    }
    var ready: Bool { guard let target else { return false }; return (try? Installer().validate(target)) != nil }

    // MARK: - Bottle management

    func scan() {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CrossOver/Bottles")
        bottles = ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("cxbottle.conf").path) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        if let prefix, !bottles.contains(prefix) { bottles.append(prefix) }
    }

    func selectBottle(_ url: URL) {
        prefix = url; steam = nil; overrides = [:]; backup = nil
        if !bottles.contains(url) { bottles.append(url) }
        for path in ["drive_c/Program Files (x86)/Steam", "drive_c/Program Files/Steam"] {
            let candidate = url.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("steam.exe").path) {
                steam = candidate; break
            }
        }
        defaults.set(url.path, forKey: "prefix")
        defaults.set(steam?.path, forKey: "steam")
        refreshLocalState()
    }

    func chooseBottle() {
        if let url = choose(directory: true) {
            guard FileManager.default.fileExists(atPath: url.appendingPathComponent("cxbottle.conf").path) else {
                report(ToolError(message: "Pilih folder bottle CrossOver yang berisi cxbottle.conf.")); return
            }
            selectBottle(url)
        }
    }

    func chooseSteam() {
        guard let prefix else { return }
        if let url = choose(directory: true) {
            guard Installer.inside(url, prefix.appendingPathComponent("drive_c")),
                  FileManager.default.fileExists(atPath: url.appendingPathComponent("steam.exe").path) else {
                report(ToolError(message: "Pilih folder berisi steam.exe di dalam drive_c bottle terpilih.")); return
            }
            steam = url; defaults.set(url.path, forKey: "steam"); refreshLocalState()
        }
    }

    func chooseCrossOver() {
        if let url = choose(directory: false) {
            guard FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine").path) else {
                report(ToolError(message: "Pilih aplikasi CrossOver.app yang valid.")); return
            }
            crossOverApp = url; overrides = [:]; defaults.set(url.path, forKey: "crossOverApp")
        }
    }

    func choose(directory: Bool) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directory; panel.canChooseFiles = !directory
        panel.showsHiddenFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Local state

    func refreshLocalState() {
        guard let steam else {
            installedLua = []
            installedVersion = nil
            return
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: steam.appendingPathComponent("config/stplug-in"),
            includingPropertiesForKeys: nil)) ?? []
        installedLua = Set(urls.filter { $0.pathExtension.lowercased() == "lua" }
                                .map { $0.deletingPathExtension().lastPathComponent })
        // Restore cached game names
        let ids = installedLua
        var names: [String: String] = [:]
        for appID in ids {
            if let saved = defaults.string(forKey: "gameName:\(appID)") {
                names[appID] = saved
            }
        }
        luaNames = names
        installedVersion = defaults.string(forKey: "version:" + steam.path)
    }

    func report(_ error: Error) { failed = true; status = error.localizedDescription }

    // MARK: - Search

    func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !searching else { return }
        searching = true; failed = false; games = []; searched = false
        Task {
            defer { searching = false; searched = true }
            do {
                games = try await catalog.search(term)
                status = games.isEmpty
                    ? LF(.statusSearchEmpty, term)
                    : "\(games.count) hasil untuk \u{201C}\(term)\u{201D}. Ketersediaan Lua diperiksa saat diunduh."
            } catch { report(error) }
        }
    }

    // MARK: - Release check

    func checkRelease() {
        guard !checkingRelease else { return }
        checkingRelease = true
        Task {
            defer { checkingRelease = false }
            do {
                release = try await catalog.latestRelease()
                _ = try release?.package()
                failed = false; status = LF(.statusCheckRelease, release!.tag_name)
            } catch { report(error) }
        }
    }

    // MARK: - Install modules

    func installModules() {
        guard let target, !busy else { return }
        busy = true; failed = false; overrides = [:]
        status = "Memeriksa rilis terbaru di GitHub\u{2026}"
        Task {
            defer { busy = false }
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("MacSteamTools-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            do {
                try Installer().validate(target)
                let latest = try await catalog.latestRelease()
                release = latest
                status = LF(.statusDownloading, latest.tag_name)
                try await catalog.downloadModules(latest, to: temporary)
                status = L(.statusInstalling)
                let saved = try await Task.detached { try Installer().install(target: target, source: temporary) }.value
                backup = saved
                defaults.set(latest.tag_name, forKey: "version:" + target.steam.path)
                overrides = Dictionary(uniqueKeysWithValues: Installer.dlls.map { ($0, "native,builtin") })
                refreshLocalState()
                status = LF(.statusModulesDone, latest.tag_name)
            } catch { report(error) }
        }
    }

    // MARK: - Install Lua

    func installLua(_ game: Game) {
        guard let target, !busy else { return }
        busy = true; failed = false
        status = "Mengunduh Lua untuk \(game.name)\u{2026}"
        Task {
            defer { busy = false }
            do {
                let data = try await catalog.lua(for: game)
                let saved = try await Task.detached { try Installer().installLua(target: target, appID: game.id, data: data) }.value
                backup = saved
                defaults.set(game.name, forKey: "gameName:\(game.id)")
                refreshLocalState()
                status = LF(.statusLuaDone, game.name, game.id)
            } catch { report(error) }
        }
    }

    // MARK: - Uninstall Lua (single)

    func uninstallLua(appID: String) {
        guard let steam, !busy else { return }
        busy = true; failed = false
        status = "Menghapus \(appID).lua\u{2026}"
        Task {
            defer { busy = false }
            do {
                let fm = FileManager.default
                let luaFile = steam.appendingPathComponent("config/stplug-in/\(appID).lua")
                if fm.fileExists(atPath: luaFile.path) {
                    try fm.removeItem(at: luaFile)
                }
                // Remove any backup entries for this appID
                let backupDir = steam.appendingPathComponent("MacSteamTools Backups")
                if fm.fileExists(atPath: backupDir.path) {
                    let entries = (try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)) ?? []
                    for entry in entries {
                        let luaBackup = entry.appendingPathComponent("\(appID).lua")
                        if fm.fileExists(atPath: luaBackup.path) {
                            try? fm.removeItem(at: entry)
                        }
                    }
                }
                refreshLocalState()
                status = "\(appID).lua berhasil dihapus."
            } catch { report(error) }
        }
    }

    // MARK: - Uninstall All (modules + lua + backups)

    func uninstallAll() {
        guard let target, !busy else { return }
        busy = true; failed = false
        status = "Menghapus semua modul dan Lua\u{2026}"
        Task {
            defer { busy = false }
            let fm = FileManager.default
            var errors: [String] = []

            // 1. Remove DLL files from Steam root and clear registry overrides
            for dll in Installer.dlls {
                let dllFile = target.steam.appendingPathComponent(dll)
                if fm.fileExists(atPath: dllFile.path) {
                    do { try fm.removeItem(at: dllFile) }
                    catch { errors.append(error.localizedDescription) }
                }
                
                // Clear Wine DLL override
                let value = String(dll.dropLast(4))
                _ = try? Installer().checked(target, ["reg", "delete", Installer.key, "/v", value, "/f"])
            }

            // 2. Remove all Lua files
            let luaDir = target.steam.appendingPathComponent("config/stplug-in")
            if fm.fileExists(atPath: luaDir.path) {
                let luas = (try? fm.contentsOfDirectory(at: luaDir, includingPropertiesForKeys: nil)) ?? []
                for lua in luas where lua.pathExtension.lowercased() == "lua" {
                    do { try fm.removeItem(at: lua) }
                    catch { errors.append(error.localizedDescription) }
                }
            }

            // 3. Remove entire MacSteamTools Backups folder
            let backupRoot = target.steam.appendingPathComponent("MacSteamTools Backups")
            if fm.fileExists(atPath: backupRoot.path) {
                do { try fm.removeItem(at: backupRoot) }
                catch { errors.append(error.localizedDescription) }
            }

            // 4. Remove version from UserDefaults
            defaults.removeObject(forKey: "version:" + target.steam.path)

            backup = nil
            refreshLocalState()
            overrides = [:]

            if errors.isEmpty {
                status = "Semua modul, Lua, dan backup berhasil dihapus."
            } else {
                failed = true
                status = "Uninstall selesai dengan beberapa error: " + errors.joined(separator: "; ")
            }
        }
    }

    // MARK: - Libraries

    func checkLibraries() {
        guard let target, !busy else { return }
        busy = true; failed = false
        status = LF(.statusReadingLibraries, target.prefix.lastPathComponent)
        Task {
            defer { busy = false }
            do {
                overrides = try await Task.detached { try Installer().readOverrides(target) }.value
                status = overrides.values.allSatisfy { $0 == "native,builtin" }
                    ? L(.statusLibrariesOk)
                    : L(.statusLibrariesBad)
            } catch { report(error) }
        }
    }

    // MARK: - Launch

    func launch(winecfg: Bool = false) {
        guard let target, !busy else { return }
        busy = true; failed = false
        Task {
            defer { busy = false }
            do {
                try await Task.detached {
                    try Installer().validate(target)
                    let relative = String(
                        target.steam.resolvingSymlinksInPath().path
                            .dropFirst(target.prefix.appendingPathComponent("drive_c").resolvingSymlinksInPath().path.count))
                    let path = winecfg ? "winecfg.exe" : "C:" + relative.replacingOccurrences(of: "/", with: "\\") + "\\steam.exe"
                    try Installer().checked(target, ["start", path])
                }.value
                status = winecfg ? L(.statusWinecfgOpened) : LF(.statusLaunched, target.prefix.lastPathComponent)
            } catch { report(error) }
        }
    }

}
