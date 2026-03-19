# Mac Cleaner CLI

Ung dung dong lenh quet va don dep du lieu rac tren macOS. Viet bang Swift, chay native khong can cai them thu vien.

## Cai dat

### Build tu source

```bash
git clone <repo-url>
cd mac-cleaner
swift build -c release
cp .build/release/mac-cleaner /usr/local/bin/mac-cleaner
```

Hoac cai vao thu muc user:

```bash
mkdir -p ~/bin
cp .build/release/mac-cleaner ~/bin/mac-cleaner
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Su dung

### Quet du lieu rac

```bash
mac-cleaner scan
```

Ket qua hien thi tung item voi ID de xoa chon loc:

```
📋 Chi tiet tung muc:

  ▸ Xcode Derived Data
    [1]   1.51 MB     ~/Library/Developer/Xcode/DerivedData/SDKStatCaches.noindex
    [2]   229.20 MB   ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
    [3]   135.02 MB   ~/Library/Developer/Xcode/DerivedData/Runner-apuez...

  ▸ Homebrew Cache
    [4]   190.21 MB   ~/Library/Caches/Homebrew/downloads
    [5]   12.30 MB    ~/Library/Caches/Homebrew/Cask

📊 Tong hop theo danh muc:

  Danh muc                 Kich thuoc    So muc
  ───────────────────────────────────────────────────────
  Xcode Derived Data       365.73 MB     3 items
  Homebrew Cache           202.51 MB     2 items
  ───────────────────────────────────────────────────────
  TONG CONG                568.24 MB
```

### Quet theo danh muc

```bash
mac-cleaner scan -c xcode
mac-cleaner scan -c caches
mac-cleaner scan -c logs
```

### Xoa theo ID

Sau khi `scan`, xoa chon loc theo ID:

```bash
mac-cleaner remove 1 3 5          # xoa item co ID 1, 3, 5
mac-cleaner remove 1-10           # xoa tat ca ID tu 1 den 10
mac-cleaner remove 1-5 8 12-15   # ket hop khoang va ID don le
mac-cleaner remove 2 --dry-run    # chay thu, khong xoa that
mac-cleaner remove 2 --force      # xoa ngay khong can xac nhan
```

### Xoa tat ca

```bash
mac-cleaner clean                  # quet + hoi xac nhan roi xoa
mac-cleaner clean --dry-run        # chay thu
mac-cleaner clean --force          # xoa ngay
mac-cleaner clean -c trash         # chi xoa Trash
```

### Liet ke danh muc

```bash
mac-cleaner list
```

## Danh muc ho tro

| Danh muc      | Mo ta                                              |
|---------------|----------------------------------------------------|
| `caches`      | ~/Library/Caches — cache cua ung dung               |
| `logs`        | ~/Library/Logs — log ung dung                        |
| `xcode`       | Xcode Derived Data + Archives                        |
| `trash`       | ~/.Trash — thung rac                                 |
| `brew`        | ~/Library/Caches/Homebrew — cache Homebrew           |
| `npm`         | ~/.npm — cache Node.js packages                      |
| `yarn`        | ~/Library/Caches/Yarn — cache Yarn                   |
| `pods`        | ~/Library/Caches/CocoaPods — cache CocoaPods         |
| `docker`      | ~/Library/Containers/com.docker.docker — Docker data |
| `ios-backup`  | ~/Library/Application Support/MobileSync/Backup      |
| `crash`       | ~/Library/Logs/DiagnosticReports — crash reports     |

## Cau truc project

```
mac-cleaner/
├── Package.swift
└── Sources/mac-cleaner/
    ├── mac_cleaner.swift    — CLI entry point (scan, clean, remove, list)
    ├── Scanner.swift        — 12 scanner modules + ScanItem/ScanCache
    ├── Cleaner.swift        — Logic xoa file/folder theo ID hoac tat ca
    └── Utilities.swift      — Format bytes, ANSI colors, helpers
```

## Yeu cau

- macOS 13+
- Swift 6.2+ (Xcode 16+)

## Luu y

- Lenh `scan` chi hien thi, khong xoa bat ky thu gi
- Lenh `remove` cho phep chon chinh xac item can xoa theo ID
- Dung `--dry-run` de xem truoc nhung gi se bi xoa
- Docker Data co the rat lon — can than khi xoa neu ban van dang dung Docker
- iOS Backups nen duoc kiem tra truoc khi xoa de tranh mat du lieu quan trong

## License

MIT
