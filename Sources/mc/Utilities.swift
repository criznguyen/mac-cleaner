import Foundation

// MARK: - Formatting

func formatBytes(_ bytes: UInt64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var size = Double(bytes)
    var unitIndex = 0
    while size >= 1024 && unitIndex < units.count - 1 {
        size /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 {
        return "\(bytes) B"
    }
    return String(format: "%.2f %@", size, units[unitIndex])
}

// MARK: - Colors (ANSI)

enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case bold = "\u{001B}[1m"
    case reset = "\u{001B}[0m"
    case dim = "\u{001B}[2m"
}

func colored(_ text: String, _ color: ANSIColor) -> String {
    "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

// MARK: - File size calculation

func directorySize(at url: URL) -> UInt64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
        options: [.skipsHiddenFiles],
        errorHandler: nil
    ) else { return 0 }

    var total: UInt64 = 0
    for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
              !(values.isDirectory ?? false),
              let size = values.fileSize else { continue }
        total += UInt64(size)
    }
    return total
}

func fileOrDirectorySize(at path: String) -> UInt64 {
    let url = URL(fileURLWithPath: path)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
    if isDir.boolValue {
        return directorySize(at: url)
    } else {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.size] as? UInt64 ?? 0
    }
}

// MARK: - User prompt

func askConfirmation(_ message: String) -> Bool {
    print(colored(message, .yellow), terminator: " ")
    guard let input = readLine()?.lowercased() else { return false }
    return input == "y" || input == "yes"
}
