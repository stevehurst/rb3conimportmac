# RB3 Custom Song Manager and Remote Storage Importer for Mac

A macOS app for managing a local library of custom Rock Band 3 songs and syncing them to an Xbox 360 USB drive — no Windows required.

Also includes a Python CLI script for quick imports.

---

## Why This Exists

Every existing method for managing Rock Band 3 custom content on Xbox 360 requires Windows — C3 CON Tools, Horizon, Modio. Velocity (a cross-platform option) no longer supports the FAT32 format Xbox 360 has used for USB drives for years.

This tool fills that gap for macOS users, adding library management and metadata editing on top of basic file import.

---

## Requirements

- macOS 14 (Sonoma) or later
- An Xbox 360 USB drive **already configured on your console** (Dashboard → Settings → System → Storage → USB Storage Device → Configure Now)
- **Title Update 4** for Rock Band 3 — TU5 and later block custom content on unmodded consoles (see [Title Update](#title-update) below)
- Custom songs in `.rb3con` format (CON packages) — see [Getting Custom Songs](#getting-custom-songs)

---

## macOS App

**RB3Importer.app** is included as a pre-built app in this repo.

> **First launch:** macOS may block the app since it isn't notarized. Right-click → Open to bypass Gatekeeper.

### Library Tab

The app opens to the **Library** tab. Select a local folder containing your `.rb3con` files and the app will scan it and display your songs grouped by artist, with collapsible sections.

- **Search** songs by name, artist, or album
- **Select songs** individually or use Select All to mark them for syncing
- **Edit metadata** — click the pencil icon on any song to edit its name, artist, album, and artwork (writes directly to the STFS header)
- **Duplicate detection** — when scanning, the app detects duplicate songs (same name and artist) and prompts you to keep the most complete version (largest file size)
- **Drag and drop** — drop `.rb3con` files onto the Library tab to copy them into your library folder

### Drive Tab

Switch to the **Drive** tab to see what's currently on your Xbox 360 USB drive, sorted by artist. You can remove individual songs from the drive here.

The Drive tab also shows your selected library songs with their sync status — whether each one is already on the drive or pending sync.

### Syncing

The drive selector and **Sync to Drive** button sit above both tabs so you can see sync status from either view. When a drive is connected:

- Songs already on the drive are automatically checked in your library
- Select additional songs in the Library tab, then click **Sync to Drive**
- Each file is validated, copied to the correct Xbox 360 folder, and verified with a SHA-256 integrity check
- macOS `._` metadata files are cleaned up automatically
- `ContentCache.pkg` is deleted so the Xbox rebuilds its content index on next boot

### Building from source

Requires Xcode 14 or later.

```bash
git clone https://github.com/stevehurst/rb3conimportmac.git
cd rb3conimportmac/RB3Importer
open RB3Importer.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project RB3Importer.xcodeproj -scheme RB3Importer -configuration Release build
```

---

## Python CLI

`rb3import.py` requires Python 3 (included with macOS) and has no external dependencies.

```bash
# Preview what will happen — no files are changed
python3 rb3import.py --dry-run "RB3 Songs" "/Volumes/XBOX DRIVE"

# Import
python3 rb3import.py "RB3 Songs" "/Volumes/XBOX DRIVE"

# Remove files previously copied to the wrong folder
python3 rb3import.py --clean "RB3 Songs" "/Volumes/XBOX DRIVE"
```

---

## Title Update

Rock Band 3 Title Update 5 and later block custom CON content on unmodded consoles. **You must use Title Update 4.**

A copy of TU4 is included in `RB3_TU4/`. To install it, copy `tu00000001_00000000` to:

```
Content/0000000000000000/45410914/000B0000/tu00000001_00000000
```

### Checking which update is active

- **In-game:** The version number is shown in the bottom-right corner of the main menu.
- **On the dashboard:** Settings → System → Storage → select your device → Games → Rock Band 3 → Title Update.

### If your console has TU5 or later on its internal drive

The Xbox 360 loads the newest title update it finds across all storage. If your internal hard drive has TU5+, it will override TU4 on the USB drive.

**Fix:**
1. Dashboard → Settings → System → Storage → Internal Hard Drive
2. Games → Rock Band 3 → delete the Title Update
3. Settings → Storage → press **Y** on any device → **Clear System Cache**
4. Relaunch Rock Band 3 — it will load TU4 from the USB drive

---

## Getting Custom Songs

Custom RB3 songs are distributed as `.rb3con` files (STFS CON packages). The most complete and up-to-date source is:

- [Rhythmverse](https://rhythmverse.co/songfiles/game/rb3)

### CON vs LIVE vs Clone Hero

| Format | Description | Works on unmodded Xbox? |
|--------|-------------|------------------------|
| `.rb3con` / CON | Community custom songs | ✅ Yes |
| LIVE | Official Xbox Live DLC | ✅ Yes |
| Clone Hero (`.chart` + `song.ini`) | PC format, separate audio | ❌ Incompatible — different format entirely |

Clone Hero songs **cannot be directly converted** to RB3 CON. RB3 requires multi-track stem audio (one track per instrument) packaged as a MOGG file — Clone Hero songs use a single stereo mix. Conversion is only possible if the original isolated stems are available, and requires Windows tools (Magma C3 Roks Edition).

---

## How It Works

### Drive format

Xbox 360 USB drives use standard **FAT32** — no special filesystem or drivers needed on macOS.

### Folder structure

```
Content/
  0000000000000000/             # Shared — visible to all profiles
    45410914/                   # Rock Band 3 Title ID
      00000001/                 # CON (SavedGame) — custom songs go here
      00000002/                 # LIVE (Marketplace) — official DLC
      000B0000/                 # Title Updates
    FFFE07DF/
      00040000/
        ContentCache.pkg        # Content index — Xbox rebuilds when missing
```

### The CON/LIVE distinction

Custom songs are **CON** packages (console-signed, content type `0x00000001`). Official DLC are **LIVE** packages (Microsoft-signed, content type `0x00000002`). These must go in different folders — placing a CON in the LIVE folder (`00000002/`) causes the Xbox to validate it as Microsoft-signed content, which fails and shows **"Corrupted Download"**.

### STFS header offsets

| Offset | Size | Field |
|--------|------|-------|
| `0x000` | 4 B | Magic (`CON `, `LIVE`, or `PIRS`) |
| `0x344` | 4 B | Content Type (big-endian uint32) |
| `0x360` | 4 B | Title ID — `0x45410914` for RB3 |
| `0x411` | 0x900 B | Display Name (UTF-16BE, 18 locales × 128 B) |
| `0xD11` | 0x900 B | Display Description (UTF-16BE, 18 locales × 128 B) |
| `0x1712` | 4 B | Thumbnail Image Size |
| `0x171A` | 0x4000 B | Thumbnail Image Data (PNG/JPEG) |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Corrupted Download" on Xbox | Files placed in `00000002/` instead of `00000001/` | Use the `--clean` flag then re-import |
| Songs don't appear | Stale `ContentCache.pkg` or TU5+ active | Delete ContentCache.pkg; check TU version |
| Drive not detected by app | Drive not configured on Xbox yet | Dashboard → Storage → USB → Configure Now |
| App blocked on launch | Unsigned / not notarized | Right-click → Open |
| macOS `._` files on drive | macOS writes metadata to FAT32 volumes | Both tools clean these automatically |
| Songs missing after 256 | Xbox 360 folder file limit | Use a second USB drive |
| All songs show "Unknown Artist" | Description field empty in STFS header | Edit metadata in the app using the pencil icon |

---

## Project Structure

```
rb3conimportmac/
  RB3Importer.app/              Pre-built macOS app
  RB3Importer/                  Xcode project
    RB3Importer.xcodeproj/
    RB3Importer/
      RB3ImporterApp.swift      App entry point
      ContentView.swift         Tab shell, drive picker, sync controls
      LibraryView.swift         Library tab — artist groups, search, selection
      LibraryManager.swift      Library scanning, grouping, duplicate detection
      DriveView.swift           Drive tab — drive contents, sync status
      DriveManager.swift        Removable drive detection
      ImportManager.swift       Legacy import orchestration
      STFSPackage.swift         STFS header parsing and metadata writing
      MetadataEditorView.swift  Song metadata editor sheet
      DuplicateResolverView.swift  Duplicate resolution UI
  RB3_TU4/                     Rock Band 3 Title Update 4
  rb3import.py                  Python CLI
  README.md
```

---

## License

MIT. This project is not affiliated with or endorsed by Harmonix, MTV Games, or Microsoft.
