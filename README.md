# RB3 Importer

A macOS tool for adding custom Rock Band 3 songs (.rb3con files) to an Xbox 360 USB drive — no Windows required.

Available as a native drag-and-drop macOS app and a Python CLI script.

---

## Why This Exists

Every existing method for managing Rock Band 3 custom content on Xbox 360 requires Windows — C3 CON Tools, Horizon, Modio. Velocity (a cross-platform option) no longer supports the FAT32 format Xbox 360 has used for USB drives for years.

This tool fills that gap for macOS users.

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

### How to use

1. Open **RB3Importer.app**
2. Plug in your Xbox 360 USB drive — the app will detect it automatically if it has the Xbox `Content/` folder structure
3. Drag your `.rb3con` files into the window (or click **Add Files…**)
4. Click **Import to Drive**

The app will:
- Validate each file is a genuine RB3 CON package (checks STFS magic bytes and Title ID)
- Copy files to the correct folder on the drive (`Content/0000000000000000/45410914/00000001/`)
- Verify each copy with a SHA-256 integrity check
- Clean up macOS `._` AppleDouble metadata files that accumulate on FAT32 drives
- Delete `ContentCache.pkg` so the Xbox rebuilds its content index on next boot

### Building from source

Requires Xcode 14 or later.

```bash
git clone https://github.com/yourusername/rb3importer.git
cd rb3importer/RB3Importer
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
| `0x411` | 128 B | Display Name (UTF-16BE) |

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

---

## Project Structure

```
rb3importer/
  RB3Importer.app/        Pre-built macOS app
  RB3Importer/            Xcode project
    RB3Importer.xcodeproj/
    RB3Importer/
      RB3ImporterApp.swift
      ContentView.swift
      STFSPackage.swift   STFS header parsing
      DriveManager.swift  Removable drive detection
      ImportManager.swift Import orchestration + integrity check
  RB3_TU4/                Rock Band 3 Title Update 4
  rb3import.py            Python CLI
  README.md
```

---

## License

MIT. This project is not affiliated with or endorsed by Harmonix, MTV Games, or Microsoft.
