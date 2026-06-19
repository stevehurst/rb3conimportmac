# RB3 Custom Song Manager and Remote Storage Importer for Mac

A macOS app for managing a local library of custom Rock Band 3 songs and syncing them to an Xbox 360 USB drive — no Windows required.

Also includes a Python CLI script for quick imports.

---

## Why This Exists

Every existing method for managing Rock Band 3 custom content on Xbox 360 requires Windows — C3 CON Tools, Horizon, Modio. Velocity (a cross-platform option) no longer supports the FAT32 format Xbox 360 has used for USB drives for years.

This tool fills that gap for macOS users: library management, song metadata display, and drive sync all in one place.

---

## Requirements

- macOS 14 (Sonoma) or later
- An Xbox 360 USB drive **already configured on your console** (see [USB Drive Setup](#usb-drive-setup))
- **Title Update 4** for Rock Band 3 — TU5 and later block custom content on unmodded consoles (see [Title Update](#title-update))
- Custom songs in `.rb3con` format — see [Getting Custom Songs](#getting-custom-songs)

---

## USB Drive Setup

Before the app or Xbox can use a USB drive for content, the Xbox 360 must format and configure it.

1. Plug the USB drive into your Xbox 360
2. Go to **Settings → System → Storage**
3. Select **USB Storage Device**
4. Choose **Configure Now**
5. Select how much space to dedicate (up to 16 GB) — the Xbox creates the required folder structure

Once configured, the drive will have a `Content/` folder that the Xbox and this app both recognize. Eject it from the Xbox and plug it into your Mac.

---

## Rock Band 3 Custom Song Setup

### What you need

- Rock Band 3 disc or digital copy
- A configured Xbox 360 USB drive (above)
- Title Update 4 on the USB drive (below)
- Custom songs in `.rb3con` format

### Step-by-step

1. **Install Title Update 4** — see [Title Update](#title-update). Without it, custom songs will not load.
2. **Get custom songs** — see [Getting Custom Songs](#getting-custom-songs). Download `.rb3con` files to a folder on your Mac.
3. **Open the app**, select your songs folder as your library, select songs, and sync to your USB drive.
4. **Eject the drive** safely from macOS (drag to Trash or right-click → Eject).
5. **Plug the drive into your Xbox 360** and launch Rock Band 3.
6. Custom songs appear in the **Music Library** — filter by source or search by name.

### Notes

- The Xbox loads content from USB drives configured under the **shared profile** (`0000000000000000`), so songs are available regardless of which gamertag is signed in.
- If songs don't appear, check that `ContentCache.pkg` has been deleted from the drive (the app does this automatically on each sync). The Xbox rebuilds it on next boot.
- The Xbox 360 has a **256-file limit per folder**. If you have more than ~256 custom songs, split them across two USB drives.

---

## Using Custom Songs Alongside Your Existing DLC and RB1/RB2 Exports

If you already own official Rock Band DLC or have exported songs from Rock Band 1 or 2, you can play them next to your customs — but there's an important catch, because **Title Updates, save files, and content licenses are three completely separate systems.**

### How these systems actually relate

- **Title Update** — the console loads the **highest-numbered Title Update it finds across *all* connected storage** (internal HDD + every USB drive). It does **not** look at your save file to decide this. Custom CON songs only load under **TU4**; TU5+ and the plain on-disc version both block them. So **if your customs load, TU4 is active** — that fact alone proves you are *not* running the on-disc version.
- **Save file** — holds your band, characters, scores, and setlists only. It carries **no licenses and no Title Update information.** Copying your save to a USB drive will not change which TU loads or make licensed content play.
- **Licenses** — official DLC and RB1/RB2 export songs are **licensed content**, bound to **(1) the gamertag** that bought/exported them and **(2) the console** they were originally downloaded/exported to.

### Why DLC and exports work on TU5 but not TU4

If your DLC and exports load fine under **TU5** but stop loading under **TU4** — on the **same console** you originally downloaded them on — the cause is the **offline (machine) license**, not the Title Update itself.

Xbox 360 licensed content carries two kinds of license:

- A **profile license** — lets the owning gamertag play the content **online, anywhere**.
- A **machine (console) license** — lets the content play **offline** on that specific console, for any profile.

Now apply that to each update:

- **TU5 → you're online** → the game verifies your **profile license** live → DLC and exports play. ✅
- **TU4 → you must be offline** (going online forces the TU5 upgrade) → offline playback requires the **machine license** stored locally on the console → if it's missing, the content shows in the list but **won't load**. ❌

The machine license commonly goes missing after a past **license transfer, system-cache clear, or storage migration** — even on the console where everything was originally downloaded.

### The fix: write the offline license, then revert to TU4

The license step requires Xbox Live, so do it **before** downgrading:

1. **Go online (you'll be on TU5).** Sign in with the gamertag that owns the DLC/exports.
2. **Run a License Transfer to *this* console** — Guide button → **Settings → Account → License Transfer** ("download your licenses to this Xbox"). This re-binds all your content's **machine licenses** to the current console.
   - *Alternative:* re-download every DLC and export pack from **Download History** — that also deposits the offline license. The formal License Transfer tool is limited to about **once per 12 months**; the Download History re-download is the repeatable method.
3. **Confirm** the DLC/exports still play while online.
4. **Reinstall TU4** (see [Title Update](#title-update)) and sync your customs, then **stay offline.**
5. Both now load under TU4 — customs because TU4 allows them, DLC/exports because the offline machine license is finally present.

### Homebrewed / RGH consoles

If your console is modded, skip the downgrade dance entirely. [RB3Enhanced](https://rb3e.rbenhanced.rocks/) and [Rock Band 3 Deluxe](https://rb3dx.milohax.org/) run custom songs on the **latest** update, so you keep TU5 (and all your DLC) and gain customs at the same time — plus a much higher song cap. These require a homebrewed (RGH/JTAG) console and do **not** work on stock retail hardware.

---

## macOS App

**RB3Importer.app** is included as a pre-built app in this repo.

> **First launch:** macOS may block the app since it isn't notarized. Right-click → Open to bypass Gatekeeper.

### Library Tab

The app opens to the **Library** tab. Select a local folder containing your `.rb3con` files and the app will scan it and display your songs grouped by artist, with collapsible sections.

- **Search** songs by name, artist, or album
- **Select songs** individually or use **Select All** to mark them for syncing
- **Song info** — click the ⓘ icon on any song to view its Rock Band metadata (track name, artist, album, year, genre, length) read directly from the embedded song data, along with file metadata and artwork
- **Duplicate detection** — on scan, the app detects duplicate songs (same name and artist) and prompts you to keep the most complete version (largest file size)
- **Drag and drop** — drop `.rb3con` files onto the Library tab to copy them into your library folder
- **Auto-refresh** — the app watches your library folder and updates automatically when files are added or removed

### Drive Tab

Switch to the **Drive** tab to see what's currently on your Xbox 360 USB drive, sorted by artist. You can remove individual songs from the drive here.

The Drive tab also shows your selected library songs with their sync status — whether each one is already on the drive or pending sync.

### Syncing

The drive selector and **Sync to Drive** button sit above both tabs so you can see sync status from either view. When a drive is connected:

- Songs already on the drive are automatically checked in your library
- Select additional songs in the Library tab, then click **Sync to Drive**
- Each file is copied to the correct Xbox 360 folder and verified with a SHA-256 integrity check
- macOS `._` metadata files are cleaned from the entire RB3 content folder automatically after each sync
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

A copy of TU4 is included in `RB3_TU4/`. The app does **not** install it automatically — copy it to your drive once manually:

```
Content/0000000000000000/45410914/000B0000/tu00000001_00000000
```

In Finder, enable hidden files with **Cmd+Shift+.** to see the `Content/` folder on the drive.

### Checking which update is active

- **In-game:** The version number appears in the bottom-right corner of the main menu. You want **v1.0.4.x**.
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

Custom RB3 songs are distributed as `.rb3con` files (STFS CON packages). The best sources:

- [Rhythmverse](https://rhythmverse.co/songfiles/game/rb3) — large catalog, searchable by song/artist/instrument
- [C3 Universe](https://www.c3universe.com/rb3/) — long-running community archive

Download `.rb3con` files to a folder on your Mac, then point the app at that folder as your library.

### CON vs LIVE vs Clone Hero

| Format | Description | Works on unmodded Xbox? |
|--------|-------------|------------------------|
| `.rb3con` / CON | Community custom songs | ✅ Yes |
| LIVE | Official Xbox Live DLC | ✅ Yes |
| Clone Hero (`.chart` + `song.ini`) | PC format, separate audio | ❌ Incompatible |

Clone Hero songs **cannot be directly converted** to RB3 CON. RB3 requires multi-track stem audio (one track per instrument) packaged as a MOGG file — Clone Hero songs typically use a single stereo mix. Conversion is only possible if the original isolated stems are available and requires Windows tools (Magma C3 Roks Edition).

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
| "Corrupted Download" on Xbox | Files in wrong folder or malformed package | Ensure CON files are in `00000001/`; use `--clean` flag to fix misplaced files |
| Songs don't appear | Stale `ContentCache.pkg` or TU5+ active | Delete ContentCache.pkg; check TU version |
| Drive not detected by app | Drive not configured on Xbox yet | Dashboard → Storage → USB → Configure Now |
| App blocked on launch | Unsigned / not notarized | Right-click → Open |
| macOS `._` files on drive | macOS writes metadata to FAT32 volumes | Both tools clean these automatically |
| Songs missing after 256 | Xbox 360 folder file limit | Split across a second USB drive |
| DLC / exports play on TU5 but not TU4 | Offline (machine) license missing — TU4 runs offline and needs a locally-stored license | License Transfer to this console while online, then revert to TU4 — see [Using Custom Songs Alongside Your Existing DLC](#using-custom-songs-alongside-your-existing-dlc-and-rb1rb2-exports) |
| Song info shows "Could not read encoded song data" | Package uses non-standard DTA encoding | Cosmetic only — song still works in-game |

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
      STFSPackage.swift         STFS header and embedded song data parsing
      MetadataEditorView.swift  Song info viewer sheet
      DuplicateResolverView.swift  Duplicate resolution UI
  RB3_TU4/                     Rock Band 3 Title Update 4
  rb3import.py                  Python CLI
  README.md
```

---

## License

MIT. This project is not affiliated with or endorsed by Harmonix, MTV Games, or Microsoft.
