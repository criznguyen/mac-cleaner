import Foundation

struct Cleaner {
    let dryRun: Bool

    func clean(results: [ScanResult]) -> UInt64 {
        var totalCleaned: UInt64 = 0
        let fm = FileManager.default

        for result in results where !result.isEmpty {
            print(colored("  Cleaning \(result.category)...", .cyan))
            for item in result.items {
                totalCleaned += deleteItem(item, fm: fm)
            }
        }
        return totalCleaned
    }

    func cleanByIDs(ids: Set<Int>, items: [ScanItem]) -> UInt64 {
        var totalCleaned: UInt64 = 0
        let fm = FileManager.default
        let selected = items.filter { ids.contains($0.id) }

        if selected.isEmpty {
            print(colored("  Không tìm thấy item nào với ID đã chọn.", .yellow))
            return 0
        }

        for item in selected {
            totalCleaned += deleteItem(item, fm: fm)
        }
        return totalCleaned
    }

    private func deleteItem(_ item: ScanItem, fm: FileManager) -> UInt64 {
        if dryRun {
            print(colored("    [DRY RUN] Would delete: ", .dim) + "[\(item.id)] " + item.displayPath + " (\(formatBytes(item.size)))")
            return item.size
        }
        do {
            try fm.removeItem(atPath: item.path)
            print(colored("    ✓ Deleted: ", .green) + "[\(item.id)] " + item.displayPath + colored(" (\(formatBytes(item.size)))", .dim))
            return item.size
        } catch {
            print(colored("    ✗ Failed: ", .red) + "[\(item.id)] " + item.displayPath)
            print(colored("      \(error.localizedDescription)", .dim))
            return 0
        }
    }
}
