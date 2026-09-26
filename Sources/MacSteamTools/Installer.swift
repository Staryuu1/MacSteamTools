import Foundation

struct ToolError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
struct Target {
    var prefix: URL
    var steam: URL
    var runtime: URL
    func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for key in ["CX_BOTTLE", "CX_BOTTLE_PATH", "CX_ROOT", "CX_INITIALIZED", "WINEDLLOVERRIDES", "WINEPREFIX"] { env.removeValue(forKey: key) }
        env["WINEPREFIX"] = prefix.path
        env["CX_BOTTLE"] = prefix.lastPathComponent
        env["CX_BOTTLE_PATH"] = prefix.deletingLastPathComponent().path
        return env
    }
}
struct CommandResult { let status: Int32; let output: String }
typealias Runner = (Target, [String]) throws -> CommandResult

func runWine(_ target: Target, _ args: [String]) throws -> CommandResult {
    let process = Process()
    process.executableURL = target.runtime
    process.arguments = ["--bottle", target.prefix.lastPathComponent] + args
    process.environment = target.environment()
    process.currentDirectoryURL = target.steam
    // A file avoids a full pipe blocking Wine while waiting for termination.
    let log = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log)
    defer { try? handle.close(); try? FileManager.default.removeItem(at: log) }
    process.standardOutput = handle; process.standardError = handle
    try process.run()
    let deadline = Date().addingTimeInterval(60)
    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
    if process.isRunning {
        process.terminate()
        throw ToolError(message: "Wine melewati batas 60 detik. Periksa bottle sebelum mencoba lagi.")
    }
    return CommandResult(status: process.terminationStatus, output: (try? String(contentsOf: log, encoding: .utf8)) ?? "")
}

struct Installer {
    static let dlls = ["dwmapi.dll", "xinput1_4.dll", "OpenSteamTool.dll"]
    static let key = "HKCU\\Software\\Wine\\DllOverrides"
    let runner: Runner
    init(runner: @escaping Runner = runWine) { self.runner = runner }

    static func inside(_ child: URL, _ parent: URL) -> Bool {
        // Resolve ancestors too: Foundation may leave a missing leaf unresolved.
        func canonical(_ url: URL) -> URL {
            url.standardizedFileURL.pathComponents.dropFirst().reduce(URL(fileURLWithPath: "/")) {
                $0.appendingPathComponent($1).resolvingSymlinksInPath()
            }
        }
        return canonical(child).path.hasPrefix(canonical(parent).path + "/")
    }
    func validate(_ target: Target) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: target.prefix.appendingPathComponent("cxbottle.conf").path),
              fm.fileExists(atPath: target.prefix.appendingPathComponent("system.reg").path),
              fm.fileExists(atPath: target.prefix.appendingPathComponent("user.reg").path),
              Self.inside(target.steam, target.prefix.appendingPathComponent("drive_c")),
              fm.fileExists(atPath: target.steam.appendingPathComponent("steam.exe").path) else {
            throw ToolError(message: "Pilih bottle CrossOver yang valid dan folder Steam di dalam drive_c yang berisi steam.exe.")
        }
        guard fm.isExecutableFile(atPath: target.runtime.path) else { throw ToolError(message: "CrossOver tidak ditemukan. Pilih CrossOver.app di Settings.") }
    }
    func checked(_ target: Target, _ args: [String]) throws {
        let result = try runner(target, args)
        guard result.status == 0 else { throw ToolError(message: "Wine gagal: \(args.joined(separator: " "))\n\(result.output.suffix(2000))") }
    }

    func readOverrides(_ target: Target) throws -> [String: String] {
        try validate(target)
        try checked(target, ["reg", "query", "HKCU\\Software\\Wine"])
        var values: [String: String] = [:]
        for name in Self.dlls {
            let result = try runner(target, ["reg", "query", Self.key, "/v", String(name.dropLast(4))])
            if result.status == 1 { values[name] = "Belum diatur"; continue }
            guard result.status == 0, let range = result.output.range(of: "REG_SZ") else {
                throw ToolError(message: "Tidak dapat membaca Libraries untuk \(name).")
            }
            values[name] = result.output[range.upperBound...].components(separatedBy: .newlines).first!
                .trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "").lowercased()
        }
        return values
    }

    func installLua(target: Target, appID: String, data: Data) throws -> URL {
        try validate(target)
        try Catalog.validateLua(data, appID: appID)
        let fm = FileManager.default
        let destination = target.steam.appendingPathComponent("config/stplug-in/\(appID).lua")
        let backup = target.steam.appendingPathComponent("MacSteamTools Backups/\(UUID().uuidString)")
        guard Self.inside(destination, target.steam), Self.inside(backup, target.steam) else {
            throw ToolError(message: "Folder Lua atau backup mengarah keluar folder Steam.")
        }
        let exists = fm.fileExists(atPath: destination.path)
        if exists, try destination.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile != true {
            throw ToolError(message: "Tujuan Lua bukan file biasa.")
        }
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        if exists { try fm.copyItem(at: destination, to: backup.appendingPathComponent("\(appID).lua")) }
        let manifest = [["destination": destination.path, "backup": exists ? "\(appID).lua" : ""]]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]).write(to: backup.appendingPathComponent("files.json"))
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        return backup
    }

    func install(target: Target, source: URL) throws -> URL {
        try validate(target)
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey])
        var copies: [(URL, URL)] = []
        for name in Self.dlls {
            let matches = files.filter { $0.lastPathComponent.lowercased() == name.lowercased() }
            guard matches.count == 1, let file = matches.first,
                  try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                throw ToolError(message: "Folder hasil ekstrak harus berisi tepat satu \(name).")
            }
            let handle = try FileHandle(forReadingFrom: file)
            let signature = try handle.read(upToCount: 2)
            try handle.close()
            guard signature == Data([0x4d, 0x5a]) else { throw ToolError(message: "\(name) bukan file DLL Windows (header MZ tidak ditemukan).") }
            copies.append((file, target.steam.appendingPathComponent(name)))
        }
        let config = target.steam.appendingPathComponent("config/stplug-in")
        guard Self.inside(config, target.steam) else { throw ToolError(message: "Folder config mengarah keluar folder Steam.") }
        for (src, dst) in copies {
            guard Self.inside(dst, target.steam), src.resolvingSymlinksInPath() != dst.resolvingSymlinksInPath() else {
                throw ToolError(message: "Sumber dan tujuan harus berbeda, dan tujuan harus berada di folder Steam.")
            }
            if fm.fileExists(atPath: dst.path), try dst.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile != true {
                throw ToolError(message: "Tujuan bukan file biasa: \(dst.path)")
            }
        }
        // Query the whole key first: status 1 on individual queries alone cannot
        // distinguish an absent value from a broken runtime.
        try checked(target, ["reg", "query", "HKCU\\Software\\Wine"])
        let backup = target.steam.appendingPathComponent("MacSteamTools Backups/\(UUID().uuidString)")
        guard Self.inside(backup, target.steam) else { throw ToolError(message: "Folder backup mengarah keluar folder Steam.") }
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        var previous: [String: String] = [:]
        for name in Self.dlls {
            let value = String(name.dropLast(4))
            let result = try runner(target, ["reg", "query", Self.key, "/v", value])
            if result.status == 0 {
                guard let range = result.output.range(of: "REG_SZ") else { throw ToolError(message: "Tipe override \(value) tidak didukung.") }
                previous[value] = result.output[range.upperBound...].components(separatedBy: .newlines).first!.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if result.status != 1 { throw ToolError(message: "Tidak dapat membaca override \(value).") }
        }
        let data = try JSONSerialization.data(withJSONObject: previous, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: backup.appendingPathComponent("overrides-before.json"))
        var existing = Set<Int>()
        for (index, pair) in copies.enumerated() where fm.fileExists(atPath: pair.1.path) {
            try fm.copyItem(at: pair.1, to: backup.appendingPathComponent("\(index)-\(pair.1.lastPathComponent)"))
            existing.insert(index)
        }
        let manifest = copies.enumerated().map { ["destination": $0.element.1.path, "backup": existing.contains($0.offset) ? "\($0.offset)-\($0.element.1.lastPathComponent)" : ""] }
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]).write(to: backup.appendingPathComponent("files.json"))
        var changedValues: [String] = []
        var changedFiles: [Int] = []
        do {
            for name in Self.dlls {
                let value = String(name.dropLast(4))
                changedValues.append(value)
                try checked(target, ["reg", "add", Self.key, "/v", value, "/t", "REG_SZ", "/d", "native,builtin", "/f"])
            }
            // Read back what winecfg's Libraries panel uses; never report success
            // based only on reg add's exit status.
            let overrides = try readOverrides(target)
            guard overrides.values.allSatisfy({ $0 == "native,builtin" }), overrides.count == Self.dlls.count else {
                throw ToolError(message: "Verifikasi Libraries gagal. Ketiga DLL harus native,builtin.")
            }
            try fm.createDirectory(at: config, withIntermediateDirectories: true)
            for (index, pair) in copies.enumerated() {
                let content = try Data(contentsOf: pair.0)
                changedFiles.append(index)
                try content.write(to: pair.1, options: .atomic)
            }
            return backup
        } catch {
            var failures: [String] = []
            for index in changedFiles.reversed() {
                do {
                    let dst = copies[index].1
                    if existing.contains(index) { try Data(contentsOf: backup.appendingPathComponent("\(index)-\(dst.lastPathComponent)")).write(to: dst, options: .atomic) }
                    else if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                } catch { failures.append(error.localizedDescription) }
            }
            for value in changedValues.reversed() {
                do {
                    if let old = previous[value] { try checked(target, ["reg", "add", Self.key, "/v", value, "/t", "REG_SZ", "/d", old, "/f"]) }
                    else { try checked(target, ["reg", "delete", Self.key, "/v", value, "/f"]) }
                } catch { failures.append(error.localizedDescription) }
            }
            throw ToolError(message: "Instalasi gagal: \(error.localizedDescription)\n\(failures.isEmpty ? "Perubahan file/override dikembalikan." : "Pemulihan belum lengkap: " + failures.joined(separator: "\n"))\nBackup: \(backup.path)")
        }
    }
}
