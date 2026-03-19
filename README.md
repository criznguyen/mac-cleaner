# Mac Cleaner CLI

A native macOS command-line tool for scanning and cleaning junk data. Built with Swift, no external runtime required.

## Installation

### Build from source

```bash
git clone https://github.com/criznguyen/mac-cleaner.git
cd mac-cleaner
swift build -c release
cp .build/release/mac-cleaner /usr/local/bin/mac-cleaner
```

Or install to user directory:

```bash
mkdir -p ~/bin
cp .build/release/mac-cleaner ~/bin/mac-cleaner
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

### Scan for junk data

```bash
mac-cleaner scan
```

Each item is assigned an ID for selective deletion:

```
📋 Item details:

  ▸ Xcode Derived Data
    [1]   1.51 MB     ~/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex
    [2]   229.20 MB   ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
    [3]   135.02 MB   ~/Library/Developer/Xcode/DerivedData/Runner-apuez...

  ▸ Homebrew Cache
    [4]   190.21 MB   ~/Library/Caches/Homebrew/downloads
    [5]   12.30 MB    ~/Library/Caches/Homebrew/Cask

📊 Summary by category:

  Shortname     Category              Size          Items
  ────────────────────────────────────────────────────────────────────
  xcode         Xcode Derived Data    365.73 MB     3 items
  brew          Homebrew Cache        202.51 MB     2 items
  ────────────────────────────────────────────────────────────────────
                TOTAL                 568.24 MB
```

### Scan by category

```bash
mac-cleaner scan -c xcode
mac-cleaner scan -c caches
mac-cleaner scan -c logs
```

### Remove by ID

After scanning, selectively remove items by ID:

```bash
mac-cleaner remove 1 3 5          # remove items with ID 1, 3, 5
mac-cleaner remove 1-10           # remove all IDs from 1 to 10
mac-cleaner remove 1-5 8 12-15   # combine ranges and individual IDs
mac-cleaner remove 2 --dry-run    # preview without actually deleting
mac-cleaner remove 2 --force      # skip confirmation prompt
```

### Remove by category name

```bash
mac-cleaner remove caches         # remove all user caches
mac-cleaner remove npm docker     # remove npm cache + Docker data
mac-cleaner remove caches 3 5     # combine category names and IDs
```

### Clean all

```bash
mac-cleaner clean                  # scan + confirm + delete all
mac-cleaner clean --dry-run        # preview only
mac-cleaner clean --force          # skip confirmation
mac-cleaner clean -c trash         # clean only Trash
```

### List categories

```bash
mac-cleaner list
```

## Supported Categories

| Category      | Description                                        |
|---------------|----------------------------------------------------|
| `caches`      | ~/Library/Caches — application caches              |
| `logs`        | ~/Library/Logs — application logs                   |
| `xcode`       | Xcode Derived Data + Archives                       |
| `trash`       | ~/.Trash — trash bin                                |
| `brew`        | ~/Library/Caches/Homebrew — Homebrew cache          |
| `npm`         | ~/.npm — Node.js package cache                      |
| `yarn`        | ~/Library/Caches/Yarn — Yarn cache                  |
| `pods`        | ~/Library/Caches/CocoaPods — CocoaPods cache        |
| `docker`      | ~/Library/Containers/com.docker.docker — Docker data|
| `ios-backup`  | ~/Library/Application Support/MobileSync/Backup     |
| `crash`       | ~/Library/Logs/DiagnosticReports — crash reports    |

## Project Structure

```
mac-cleaner/
├── Package.swift
└── Sources/mac-cleaner/
    ├── mac_cleaner.swift    — CLI entry point (scan, clean, remove, list)
    ├── Scanner.swift        — 12 scanner modules + ScanItem/ScanCache
    ├── Cleaner.swift        — Deletion logic by ID or category
    └── Utilities.swift      — Byte formatting, ANSI colors, helpers
```

## Requirements

- macOS 13+
- Swift 6.2+ (Xcode 16+)

## Notes

- `scan` only displays results — it does not delete anything
- `remove` allows precise selection by item ID or category name
- Use `--dry-run` to preview what will be deleted before committing
- Docker Data can be very large — be careful if you still use Docker
- iOS Backups should be reviewed before deletion to avoid data loss

## License

MIT
