import ArgumentParser
import Foundation

@main
struct MacCleaner: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mc",
        abstract: "Quét và dọn dẹp dữ liệu rác trên macOS",
        version: "1.0.0",
        subcommands: [Scan.self, Clean.self, Remove.self, List.self],
        defaultSubcommand: Scan.self
    )
}

// MARK: - Scan command

extension MacCleaner {
    struct Scan: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Quét tìm dữ liệu rác (chỉ hiển thị, không xóa)"
        )

        @Option(name: .shortAndLong, help: "Chỉ quét danh mục cụ thể (vd: caches, logs, xcode, trash, brew, npm, yarn, pods, docker, ios-backup, crash)")
        var category: String?

        func run() throws {
            printBanner()
            let scanners = selectedScanners(for: category)
            let results = runScan(scanners: scanners)
            printDetailedResults(results: results)
            printSummary(results: results)

            // Save scan results for `remove` command
            let allItems = results.flatMap(\.items)
            ScanCache.save(items: allItems)
            print(colored("Tip: mc remove 1 3 5       — xóa theo ID", .dim))
            print(colored("     mc remove 1-10        — xóa theo khoảng ID", .dim))
            print(colored("     mc remove caches npm  — xóa theo danh mục", .dim))
            print(colored("     mc remove caches 3 5  — kết hợp cả hai", .dim))
            print()
        }
    }
}

// MARK: - Clean command

extension MacCleaner {
    struct Clean: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Quét và dọn dẹp tất cả dữ liệu rác"
        )

        @Option(name: .shortAndLong, help: "Chỉ dọn danh mục cụ thể")
        var category: String?

        @Flag(name: .shortAndLong, help: "Chạy thử — hiển thị những gì sẽ xóa mà không xóa thật")
        var dryRun = false

        @Flag(name: .shortAndLong, help: "Bỏ qua xác nhận, xóa ngay")
        var force = false

        func run() throws {
            printBanner()
            let scanners = selectedScanners(for: category)
            let results = runScan(scanners: scanners)
            let nonEmpty = results.filter { !$0.isEmpty }

            if nonEmpty.isEmpty {
                print(colored("\n✓ Không tìm thấy dữ liệu rác nào!\n", .green))
                return
            }

            printDetailedResults(results: results)
            printSummary(results: results)

            let totalSize = nonEmpty.reduce(UInt64(0)) { $0 + $1.totalSize }

            if !force && !dryRun {
                guard askConfirmation("\nBạn có muốn xóa \(formatBytes(totalSize)) dữ liệu? (y/N):") else {
                    print(colored("Đã hủy.", .yellow))
                    return
                }
            }

            print(colored("\n🧹 Đang dọn dẹp...\n", .bold))
            let cleaner = Cleaner(dryRun: dryRun)
            let cleaned = cleaner.clean(results: nonEmpty)
            ScanCache.clear()

            if dryRun {
                print(colored("\n[DRY RUN] Sẽ giải phóng: \(formatBytes(cleaned))\n", .yellow))
            } else {
                print(colored("\n✓ Đã giải phóng: \(formatBytes(cleaned))\n", .green))
            }
        }
    }
}

// MARK: - Remove command (delete by IDs)

extension MacCleaner {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Xóa theo ID hoặc tên danh mục từ kết quả scan"
        )

        @Argument(help: "ID (1 3 5), khoảng ID (1-10), hoặc tên danh mục (caches npm docker)")
        var targets: [String]

        @Flag(name: .shortAndLong, help: "Chạy thử — không xóa thật")
        var dryRun = false

        @Flag(name: .shortAndLong, help: "Bỏ qua xác nhận")
        var force = false

        func run() throws {
            printBanner()

            guard let cachedItems = ScanCache.load(), !cachedItems.isEmpty else {
                print(colored("⚠ Chưa có kết quả scan. Hãy chạy `mc scan` trước.\n", .yellow))
                return
            }

            // Separate numeric IDs vs category names
            let (selectedIDs, categoryNames) = parseTargets(targets)

            // Resolve category names to matching item IDs
            let categoryIDs = resolveCategoryIDs(names: categoryNames, items: cachedItems)
            let allIDs = selectedIDs.union(categoryIDs)

            if allIDs.isEmpty {
                print(colored("⚠ Không có ID hoặc danh mục hợp lệ.\n", .yellow))
                print(colored("Tip: Dùng tên danh mục như: caches, logs, xcode, trash, brew, npm, docker, ...", .dim))
                print(colored("     Hoặc ID số từ kết quả scan: 1 3 5, 1-10", .dim))
                print()
                return
            }

            let selected = cachedItems.filter { allIDs.contains($0.id) }
            if selected.isEmpty {
                print(colored("⚠ Không tìm thấy item nào.\n", .yellow))
                return
            }

            // Show what will be deleted, grouped by category
            print(colored("📋 Các mục sẽ xóa:\n", .bold))
            var totalSize: UInt64 = 0
            let grouped = Dictionary(grouping: selected, by: \.category)
            for (category, items) in grouped.sorted(by: { $0.key < $1.key }) {
                print(colored("  ▸ \(category)", .cyan))
                for item in items {
                    let sizeColor: ANSIColor = item.size > 100_000_000 ? .red : (item.size > 10_000_000 ? .yellow : .green)
                    print("    \(colored("[\(item.id)]", .bold))  \(colored(formatBytes(item.size).padding(toLength: 12, withPad: " ", startingAt: 0), sizeColor))  \(item.displayPath)")
                    totalSize += item.size
                }
            }
            print(colored("\n  Tổng: \(formatBytes(totalSize)) (\(selected.count) mục)", .bold))

            if !force && !dryRun {
                guard askConfirmation("\nXác nhận xóa \(selected.count) mục (\(formatBytes(totalSize)))? (y/N):") else {
                    print(colored("Đã hủy.", .yellow))
                    return
                }
            }

            print(colored("\n🧹 Đang xóa...\n", .bold))
            let cleaner = Cleaner(dryRun: dryRun)
            let cleaned = cleaner.cleanByIDs(ids: allIDs, items: cachedItems)

            if dryRun {
                print(colored("\n[DRY RUN] Sẽ giải phóng: \(formatBytes(cleaned))\n", .yellow))
            } else {
                print(colored("\n✓ Đã giải phóng: \(formatBytes(cleaned))\n", .green))
                let remaining = cachedItems.filter { !allIDs.contains($0.id) }
                ScanCache.save(items: remaining)
            }
        }
    }
}

// MARK: - List command

extension MacCleaner {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Liệt kê các danh mục có thể quét"
        )

        func run() {
            printBanner()
            print(colored("Danh mục hỗ trợ:\n", .bold))
            let categories: [(String, String)] = [
                ("caches", "User Caches — ~/Library/Caches"),
                ("logs", "User Logs — ~/Library/Logs"),
                ("xcode", "Xcode Derived Data + Archives"),
                ("trash", "Trash — ~/.Trash"),
                ("brew", "Homebrew Cache"),
                ("npm", "npm Cache — ~/.npm"),
                ("yarn", "Yarn Cache"),
                ("pods", "CocoaPods Cache"),
                ("docker", "Docker Data"),
                ("ios-backup", "iOS Device Backups"),
                ("crash", "Crash Reports"),
            ]
            for (key, desc) in categories {
                print("  \(colored(key.padding(toLength: 14, withPad: " ", startingAt: 0), .cyan))\(desc)")
            }
            print("\nSử dụng:")
            print("  \(colored("mc scan", .green))                  Quét tất cả")
            print("  \(colored("mc scan -c xcode", .green))         Quét theo danh mục")
            print("  \(colored("mc remove 1 3 5", .green))          Xóa theo ID")
            print("  \(colored("mc remove 1-10", .green))           Xóa theo khoảng ID")
            print("  \(colored("mc clean", .green))                 Xóa tất cả")
            print("  \(colored("mc clean --dry-run", .green))       Chạy thử")
            print()
        }
    }
}

// MARK: - Helpers

private func printBanner() {
    print(colored("""

    ╔══════════════════════════════════════╗
    ║     🧹 Mac Cleaner CLI v1.0.0       ║
    ║     Dọn dẹp dữ liệu rác macOS      ║
    ╚══════════════════════════════════════╝
    """, .cyan))
    print()
}

private func selectedScanners(for category: String?) -> [any JunkScanner] {
    idCounter.reset()
    guard let category = category else { return allScanners }
    switch category.lowercased() {
    case "caches", "cache":
        return [UserCacheScanner()]
    case "logs", "log":
        return [LogsScanner()]
    case "xcode":
        return [XcodeDerivedDataScanner(), XcodeArchivesScanner()]
    case "trash":
        return [TrashScanner()]
    case "brew", "homebrew":
        return [BrewCacheScanner()]
    case "npm":
        return [NpmCacheScanner()]
    case "yarn":
        return [YarnCacheScanner()]
    case "pods", "cocoapods":
        return [CocoaPodsCacheScanner()]
    case "docker":
        return [DockerScanner()]
    case "ios-backup", "backup":
        return [IOSBackupScanner()]
    case "crash":
        return [CrashReportsScanner()]
    default:
        print(colored("⚠ Danh mục '\(category)' không hợp lệ. Quét tất cả...\n", .yellow))
        return allScanners
    }
}

private func runScan(scanners: [any JunkScanner]) -> [ScanResult] {
    print(colored("🔍 Đang quét...\n", .bold))
    var results: [ScanResult] = []
    for scanner in scanners {
        print(colored("  Scanning: ", .dim) + scanner.description)
        let result = scanner.scan()
        results.append(result)
    }
    return results
}

private func printDetailedResults(results: [ScanResult]) {
    print(colored("\n📋 Chi tiết từng mục:\n", .bold))
    for result in results where !result.isEmpty {
        print(colored("  ▸ \(result.category)", .cyan))
        for item in result.items {
            let sizeColor: ANSIColor = item.size > 100_000_000 ? .red : (item.size > 10_000_000 ? .yellow : .green)
            let idStr = colored("[\(item.id)]".padding(toLength: 6, withPad: " ", startingAt: 0), .bold)
            let sizeStr = colored(formatBytes(item.size).padding(toLength: 12, withPad: " ", startingAt: 0), sizeColor)
            print("    \(idStr) \(sizeStr)  \(item.displayPath)")
        }
        print()
    }
}

private func printSummary(results: [ScanResult]) {
    print(colored("📊 Tổng hợp theo danh mục:\n", .bold))
    print("  \(colored("Tên tắt".padding(toLength: 14, withPad: " ", startingAt: 0), .bold))\(colored("Danh mục".padding(toLength: 22, withPad: " ", startingAt: 0), .bold))\(colored("Kích thước", .bold))    \(colored("Số mục", .bold))")
    print("  " + String(repeating: "─", count: 68))

    var grandTotal: UInt64 = 0
    for result in results {
        let sizeStr: String
        let color: ANSIColor
        if result.isEmpty {
            sizeStr = "—"
            color = .dim
        } else {
            sizeStr = formatBytes(result.totalSize)
            color = result.totalSize > 100_000_000 ? .red : (result.totalSize > 10_000_000 ? .yellow : .green)
        }
        let shortName = categoryShortName(for: result.category)
        let tag = colored(shortName.padding(toLength: 14, withPad: " ", startingAt: 0), .cyan)
        let name = result.category.padding(toLength: 22, withPad: " ", startingAt: 0)
        let size = sizeStr.padding(toLength: 14, withPad: " ", startingAt: 0)
        print("  \(tag)\(colored(name, color))\(colored(size, color))  \(colored("\(result.items.count) items", .dim))")
        grandTotal += result.totalSize
    }

    print("  " + String(repeating: "─", count: 68))
    let totalColor: ANSIColor = grandTotal > 1_000_000_000 ? .red : (grandTotal > 100_000_000 ? .yellow : .green)
    print("  \(String(repeating: " ", count: 14))\(colored("TỔNG CỘNG".padding(toLength: 22, withPad: " ", startingAt: 0), .bold))\(colored(formatBytes(grandTotal), totalColor))")
    print()
}

// MARK: - Category name mapping

private let categoryNameMap: [String: [String]] = [
    "caches":     ["User Caches"],
    "cache":      ["User Caches"],
    "logs":       ["User Logs"],
    "log":        ["User Logs"],
    "xcode":      ["Xcode Derived Data", "Xcode Archives"],
    "trash":      ["Trash"],
    "brew":       ["Homebrew Cache"],
    "homebrew":   ["Homebrew Cache"],
    "npm":        ["npm Cache"],
    "yarn":       ["Yarn Cache"],
    "pods":       ["CocoaPods Cache"],
    "cocoapods":  ["CocoaPods Cache"],
    "docker":     ["Docker Data"],
    "ios-backup": ["iOS Backups"],
    "backup":     ["iOS Backups"],
    "crash":      ["Crash Reports"],
]

private func categoryShortName(for category: String) -> String {
    for (key, values) in categoryNameMap {
        if values.contains(category) && key.count <= 10 {
            return key
        }
    }
    return category.lowercased().replacingOccurrences(of: " ", with: "-")
}

// MARK: - Parse targets (IDs + category names)

private func parseTargets(_ args: [String]) -> (Set<Int>, [String]) {
    var ids = Set<Int>()
    var names: [String] = []
    for arg in args {
        let lower = arg.lowercased()
        if let _ = Int(arg) {
            ids.insert(Int(arg)!)
        } else if arg.contains("-"), let range = parseRange(arg) {
            for id in range { ids.insert(id) }
        } else if categoryNameMap[lower] != nil {
            names.append(lower)
        } else {
            print(colored("⚠ Không nhận diện được '\(arg)' — bỏ qua", .yellow))
        }
    }
    return (ids, names)
}

private func resolveCategoryIDs(names: [String], items: [ScanItem]) -> Set<Int> {
    var ids = Set<Int>()
    for name in names {
        guard let fullNames = categoryNameMap[name] else { continue }
        for item in items where fullNames.contains(item.category) {
            ids.insert(item.id)
        }
    }
    return ids
}

private func parseRange(_ str: String) -> ClosedRange<Int>? {
    let parts = str.split(separator: "-")
    guard parts.count == 2,
          let start = Int(parts[0]),
          let end = Int(parts[1]),
          start <= end else { return nil }
    return start...end
}
