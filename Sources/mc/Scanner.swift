import Foundation

// MARK: - Scan Item (with ID)

struct ScanItem: Codable, Sendable {
    let id: Int
    let category: String
    let path: String
    let size: UInt64

    var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// MARK: - Scan Result

struct ScanResult: Sendable {
    let category: String
    let items: [ScanItem]
    let totalSize: UInt64

    var isEmpty: Bool { items.isEmpty || totalSize == 0 }
    var paths: [String] { items.map(\.path) }
}

// MARK: - Scan Cache (save/load results to temp file)

struct ScanCache {
    private static let cachePath = NSTemporaryDirectory() + "mac-cleaner-scan.json"

    static func save(items: [ScanItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: URL(fileURLWithPath: cachePath))
    }

    static func load() -> [ScanItem]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cachePath)),
              let items = try? JSONDecoder().decode([ScanItem].self, from: data) else {
            return nil
        }
        return items
    }

    static func clear() {
        try? FileManager.default.removeItem(atPath: cachePath)
    }
}

// MARK: - ID Counter

final class IDCounter: @unchecked Sendable {
    private var current = 0
    func next() -> Int {
        current += 1
        return current
    }
    func reset() { current = 0 }
}

let idCounter = IDCounter()

// MARK: - Scanner Protocol

protocol JunkScanner: Sendable {
    var name: String { get }
    var description: String { get }
    func scan() -> ScanResult
}

// MARK: - User Caches

struct UserCacheScanner: JunkScanner {
    let name = "User Caches"
    let description = "~/Library/Caches — app caches"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Caches", category: name)
    }
}

// MARK: - System Logs

struct LogsScanner: JunkScanner {
    let name = "User Logs"
    let description = "~/Library/Logs — application logs"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Logs", category: name)
    }
}

// MARK: - Xcode Derived Data

struct XcodeDerivedDataScanner: JunkScanner {
    let name = "Xcode Derived Data"
    let description = "~/Library/Developer/Xcode/DerivedData"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData", category: name, requireExists: true)
    }
}

// MARK: - Xcode Archives

struct XcodeArchivesScanner: JunkScanner {
    let name = "Xcode Archives"
    let description = "~/Library/Developer/Xcode/Archives"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Developer/Xcode/Archives", category: name, requireExists: true)
    }
}

// MARK: - Homebrew Cache

struct BrewCacheScanner: JunkScanner {
    let name = "Homebrew Cache"
    let description = "~/Library/Caches/Homebrew — brew download cache"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Caches/Homebrew", category: name, requireExists: true)
    }
}

// MARK: - Trash

struct TrashScanner: JunkScanner {
    let name = "Trash"
    let description = "~/.Trash — items in trash bin"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/.Trash", category: name)
    }
}

// MARK: - npm Cache

struct NpmCacheScanner: JunkScanner {
    let name = "npm Cache"
    let description = "~/.npm — Node.js package cache"

    func scan() -> ScanResult {
        scanSinglePath(NSHomeDirectory() + "/.npm", category: name)
    }
}

// MARK: - Yarn Cache

struct YarnCacheScanner: JunkScanner {
    let name = "Yarn Cache"
    let description = "~/Library/Caches/Yarn — Yarn package cache"

    func scan() -> ScanResult {
        scanSinglePath(NSHomeDirectory() + "/Library/Caches/Yarn", category: name)
    }
}

// MARK: - CocoaPods Cache

struct CocoaPodsCacheScanner: JunkScanner {
    let name = "CocoaPods Cache"
    let description = "~/Library/Caches/CocoaPods — pod cache"

    func scan() -> ScanResult {
        scanSinglePath(NSHomeDirectory() + "/Library/Caches/CocoaPods", category: name)
    }
}

// MARK: - Docker Data (if not running)

struct DockerScanner: JunkScanner {
    let name = "Docker Data"
    let description = "~/Library/Containers/com.docker.docker — Docker disk images"

    func scan() -> ScanResult {
        scanSinglePath(NSHomeDirectory() + "/Library/Containers/com.docker.docker", category: name)
    }
}

// MARK: - Old iOS Device Backups

struct IOSBackupScanner: JunkScanner {
    let name = "iOS Backups"
    let description = "~/Library/Application Support/MobileSync/Backup"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Application Support/MobileSync/Backup", category: name, requireExists: true)
    }
}

// MARK: - Application Support Crash Reports

struct CrashReportsScanner: JunkScanner {
    let name = "Crash Reports"
    let description = "~/Library/Logs/DiagnosticReports"

    func scan() -> ScanResult {
        scanDirectory(NSHomeDirectory() + "/Library/Logs/DiagnosticReports", category: name, requireExists: true)
    }
}

// MARK: - Scan helpers

private func scanDirectory(_ dir: String, category: String, requireExists: Bool = false) -> ScanResult {
    let fm = FileManager.default
    if requireExists {
        guard fm.fileExists(atPath: dir) else {
            return ScanResult(category: category, items: [], totalSize: 0)
        }
    }
    guard let entries = try? fm.contentsOfDirectory(atPath: dir) else {
        return ScanResult(category: category, items: [], totalSize: 0)
    }
    var items: [ScanItem] = []
    var total: UInt64 = 0
    for entry in entries {
        let fullPath = dir + "/" + entry
        let size = fileOrDirectorySize(at: fullPath)
        if size > 0 {
            items.append(ScanItem(id: idCounter.next(), category: category, path: fullPath, size: size))
            total += size
        }
    }
    return ScanResult(category: category, items: items, totalSize: total)
}

private func scanSinglePath(_ path: String, category: String) -> ScanResult {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else {
        return ScanResult(category: category, items: [], totalSize: 0)
    }
    let size = fileOrDirectorySize(at: path)
    if size > 0 {
        let item = ScanItem(id: idCounter.next(), category: category, path: path, size: size)
        return ScanResult(category: category, items: [item], totalSize: size)
    }
    return ScanResult(category: category, items: [], totalSize: 0)
}

// MARK: - All scanners

let allScanners: [any JunkScanner] = [
    UserCacheScanner(),
    LogsScanner(),
    XcodeDerivedDataScanner(),
    XcodeArchivesScanner(),
    BrewCacheScanner(),
    TrashScanner(),
    NpmCacheScanner(),
    YarnCacheScanner(),
    CocoaPodsCacheScanner(),
    DockerScanner(),
    IOSBackupScanner(),
    CrashReportsScanner(),
]
