# Rock Band 2+3 Xbox 360 Custom CON Sync for macOS

<p align="center">
  <img src="RB Con Sync Icon.png" alt="RB Con Sync 360" width="200">
</p>

A macOS app for managing a local library of custom Rock Band songs (RB1, RB2, and RB3) and syncing them to an Xbox 360 USB drive — no Windows required.

Also includes a Python CLI script for quick imports.

---

## Why This Exists

Every existing method for managing Rock Band custom content on Xbox 360 requires Windows — C3 CON Tools, Horizon, Modio. Velocity (a cross-platform option) no longer supports the FAT32 format Xbox 360 has used for USB drives for years.

This tool fills that gap for macOS users: library management, multi-game support, song metadata display, and drive sync all in one place.

---

## Requirements

- macOS 14 (Sonoma) or later
- An Xbox 360 USB drive **already configured on your console** (see [USB Drive Setup](#usb-drive-setup))
- Custom songs in `.rb2con` or `.rb3con` format (or extensionless STFS packages) — see [Getting Custom Songs](#getting-custom-songs)

### For unmodded consoles

- **Title Update 4** for Rock Band 3 — TU5 and later block custom content (see [Title Update](#title-update))

### For modded consoles (RGH/JTAG)

- [Rock Band 3 Deluxe](https://rb3dx.milohax.org/) or [Rock Band 2 Deluxe](https://rb2dx.milohax.org/) — these run custom songs on the latest update with a much higher song cap
- A softmod like [BadUpdate / XeUnshackle](https://consolemods.org/wiki/Xbox_360:BadUpdate) also works for session-based modding on stock hardware

---

## USB Drive Setup

Before the app or Xbox can use a USB drive for content, the Xbox 360 must format and configure it.

1. Plug the USB drive into your Xbox 360
2. Go to **Settings → System → Storage**
3. Select **USB Storage Device**
4. Choose **Configure Now**
5. Select how much space to dedicate (up to 16 GB or 32 GB depending on drive size) — the Xbox creates the required folder structure

Once configured, the drive will have a `Content/` folder that the Xbox and this app both recognize. Eject it from the Xbox and plug it into your Mac.

---

## macOS App

**RB Con Sync 360** (`RBConSync.app`) is included as a pre-built app in this repo.

> **First launch:** macOS may block the app since it isn't notarized. Right-click → Open to bypass Gatekeeper.

### Multi-Game Support

The app supports songs for all three Rock Band games:

| Game | Title ID | Badge Color |
|------|----------|-------------|
| Rock Band 1 | `45410829` | Orange |
| Rock Band 2 | `45410869` | Purple |
| Rock Band 3 | `45410914` | Blue |

Each song is identified by the title ID embedded in its STFS header. The app shows a colored game badge (RB1, RB2, RB3) next to every song in both the library and drive views.

**Smart sync routing:** RB3 and RB3 Deluxe scan the RB2 and RB3 content folders on the drive, but not the RB1 folder. The app automatically routes RB1-titled songs (such as RB4-to-RB2 conversions) into the RB2 content folder so RB3/RB3DX can find them. RB2 and RB3 songs go to their own respective folders.

### Library Tab

Select a local folder containing your song files and the app scans it recursively — including subfolders — and displays songs grouped by artist with collapsible sections.

- **Search** — filter songs by name, artist, album, or subfolder name
- **Subfolder labels** — each song shows its relative subfolder path next to the game badge, so you can see which library subfolder it came from
- **Select songs** individually with per-song checkboxes, or use **Select All / Deselect All**
- **Per-artist selection** — click the checkbox next to any artist name to select or deselect all their songs at once. Shows a filled check when all selected, a minus when partially selected
- **Expand / Collapse controls** — three buttons next to the search bar:
  - **Collapse All** — collapse every artist group
  - **Show Only Unsynced** — expand only artists with songs not yet on the drive or needing resync; collapse the rest
  - **Expand All** — expand every artist group
- **Song info** — click the info icon on any song to view its Rock Band metadata (track name, artist, album, year, genre, length, game, subfolder, file size, package type, and thumbnail artwork) read directly from the embedded DTA song data
- **Duplicate detection** — on scan, the app detects duplicate songs (same name and artist) and prompts you to keep the most complete version (largest file size)
- **Drag and drop** — drop song files onto the Library tab to copy them into your library folder
- **Auto-refresh** — the app watches your library folder and updates automatically when files are added or removed
- **Context menu** — right-click any song to view info, sync it immediately, or reveal it in Finder

### Drive Tab

Switch to the **Drive** tab to see what's currently on your Xbox 360 USB drive, sorted by artist. Songs show their game badge and can be individually removed from the drive.

The Drive tab also shows your selected library songs with their sync status:

- **On Drive** (green) — file exists on drive with matching size
- **Updated** (blue) — file exists but sizes differ; will be replaced on next sync
- **Pending Sync** (orange) — not yet on drive

### Drive Detection

The app detects external USB drives including large portable drives (Seagate BUP Slim, WD Passport, etc.) that report as non-removable. It checks for removable, ejectable, or non-internal volumes. Drives with an existing Xbox `Content/` folder are flagged with a controller icon.

Auto-selects the drive if only one Xbox-configured drive is connected. Use the refresh button to rescan drives and drive content.

### Syncing

The drive selector and **Sync to Drive** button sit above both tabs so you can see sync status from either view. When a drive is connected:

- Songs already on the drive are automatically checked in your library
- Live sync counts show how many songs are on drive, updated, or pending
- Select additional songs in the Library tab, then click **Sync to Drive**
- Each file is copied to the correct Xbox 360 content folder based on game and verified with a **SHA-256 integrity check**
- Filenames longer than 42 characters are truncated to fit FAT32 constraints
- macOS metadata files (`._*`, `.DS_Store`, `.Spotlight-V100`, `.Trashes`, `.fseventsd`) are cleaned from the Content folder automatically after each sync
- `ContentCache.pkg` is deleted so the Xbox rebuilds its content index on next boot
- The app does **not** auto-remove songs from the drive that aren't in your library — drive management is manual via the Drive tab

### Building from source

Requires Xcode 15 or later.

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

`rb3import.py` requires Python 3 (included with macOS) and has no external dependencies. It supports RB3 songs only (title ID `45410914`).

```bash
# Preview what will happen — no files are changed
python3 rb3import.py --dry-run "RB3 Songs" "/Volumes/XBOX DRIVE"

# Import
python3 rb3import.py "RB3 Songs" "/Volumes/XBOX DRIVE"

# Remove files previously copied to the wrong folder
python3 rb3import.py --clean "RB3 Songs" "/Volumes/XBOX DRIVE"
```

---

## How It Works

### Drive format

Xbox 360 USB drives use standard **FAT32** — no special filesystem or drivers needed on macOS.

### Folder structure

```
Content/
  0000000000000000/             # Shared — visible to all profiles
    45410869/                   # Rock Band 2 Title ID (also holds RB1 songs)
      00000001/                 # CON (SavedGame) — custom songs
    45410914/                   # Rock Band 3 Title ID
      00000001/                 # CON (SavedGame) — custom songs
      00000002/                 # LIVE (Marketplace) — official DLC
      000B0000/                 # Title Updates
    FFFE07DF/
      00040000/
        ContentCache.pkg        # Content index — Xbox rebuilds when missing
```

RB3 and RB3 Deluxe scan both the RB2 (`45410869`) and RB3 (`45410914`) content folders. RB1's title ID folder (`45410829`) is **not** scanned by RB3, which is why the app places RB1-titled songs in the RB2 folder.

### The CON/LIVE distinction

Custom songs are **CON** packages (console-signed, content type `0x00000001`). Official DLC are **LIVE** packages (Microsoft-signed, content type `0x00000002`). These must go in different folders — placing a CON in the LIVE folder (`00000002/`) causes the Xbox to validate it as Microsoft-signed content, which fails and shows **"Corrupted Download"**.

### STFS header offsets

| Offset | Size | Field |
|--------|------|-------|
| `0x000` | 4 B | Magic (`CON `, `LIVE`, or `PIRS`) |
| `0x344` | 4 B | Content Type (big-endian uint32) |
| `0x360` | 4 B | Title ID — `0x45410829` (RB1), `0x45410869` (RB2), `0x45410914` (RB3) |
| `0x411` | 0x80 B | Display Name (UTF-16BE) |
| `0xD11` | 0x80 B | Display Description (UTF-16BE) |
| `0x1712` | 4 B | Thumbnail Image Size |
| `0x171A` | 0x4000 B | Thumbnail Image Data (PNG/JPEG) |

### DTA song metadata

The app extracts embedded DTA (song definition) data from inside the STFS file table. This provides the in-game metadata: track name, artist, album, year, genre, song length, and vocal parts. Drive scanning skips DTA extraction for performance (reads only the first ~24 KB of each file for the header).

---

## Getting Custom Songs

Custom songs are distributed as STFS CON packages (`.rb3con`, `.rb2con`, or extensionless). The best sources:

- [Rhythmverse](https://rhythmverse.co/songfiles/game/rb3) — large catalog, searchable by song/artist/instrument
- [C3 Universe](https://www.c3universe.com/rb3/) — long-running community archive
- [C0Assassin/rb4-to-rb2](https://github.com/C0Assassin/rb4-to-rb2) — RB4 disc and DLC songs converted to CON format for Xbox 360

### CON vs LIVE vs Clone Hero

| Format | Description | Works on Xbox 360? |
|--------|-------------|---------------------|
| `.rb3con` / `.rb2con` / CON | Community custom songs | Yes |
| LIVE | Official Xbox Live DLC | Yes |
| Clone Hero (`.chart` + `song.ini`) | PC format, separate audio | No — incompatible |

Clone Hero songs **cannot be directly converted** to RB3 CON. RB3 requires multi-track stem audio (one track per instrument) packaged as a MOGG file — Clone Hero songs typically use a single stereo mix.

---

## Title Update

> **Modded consoles:** If you're running RB3 Deluxe or RB2 Deluxe, skip this section — those mods handle custom content on the latest update.

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

- **TU5 → you're online** → the game verifies your **profile license** live → DLC and exports play.
- **TU4 → you must be offline** (going online forces the TU5 upgrade) → offline playback requires the **machine license** stored locally on the console → if it's missing, the content shows in the list but **won't load**.

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

If your console is modded, skip the downgrade dance entirely. [RB3Enhanced](https://rb3e.rbenhanced.rocks/) and [Rock Band 3 Deluxe](https://rb3dx.milohax.org/) run custom songs on the **latest** update, so you keep TU5 (and all your DLC) and gain customs at the same time — plus a much higher song cap. These require a homebrewed (RGH/JTAG) console or a softmod like BadUpdate/XeUnshackle.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Corrupted Download" on Xbox | Files in wrong folder or malformed package | Ensure CON files are in `00000001/`; LIVE files in `00000002/` |
| Songs don't appear in RB3 | Stale `ContentCache.pkg` or TU5+ active | Delete ContentCache.pkg (app does this on sync); check TU version |
| RB1-titled songs not visible in RB3 | Songs in the RB1 content folder (`45410829`) | Move to RB2 folder (`45410869`) — the app does this automatically |
| Drive not detected by app | Drive not configured on Xbox yet | Dashboard → Storage → USB → Configure Now |
| App blocked on launch | Unsigned / not notarized | Right-click → Open |
| macOS `._` files on drive | macOS writes metadata to FAT32 volumes | Cleaned automatically on each sync |
| "Updated" count won't clear after sync | File size mismatch (truncated filename, FAT32 write issue) | Re-sync — the app uses direct writes with explicit delete + SHA-256 verification |
| Slow drive scan | Large number of songs on USB 2.0 drive | Drive scanning reads only headers (~24 KB per file) for speed |
| DLC / exports play on TU5 but not TU4 | Offline (machine) license missing | License Transfer while online, then revert to TU4 — see [above](#using-custom-songs-alongside-your-existing-dlc-and-rb1rb2-exports) |
| Song info shows "Could not read encoded song data" | Package uses non-standard DTA encoding | Cosmetic only — song still works in-game |
| RB3DX crash loading songs | Too many songs or a bad CON file | Try syncing songs in batches to isolate the problem file |

---

## Project Structure

```
rb3conimportmac/
  RBConSync.app/                Pre-built macOS app (RB Con Sync 360)
  RB3Importer/                  Xcode project
    RB3Importer.xcodeproj/
    RB3Importer/
      RB3ImporterApp.swift      App entry point
      ContentView.swift         Tab shell, drive picker, sync controls
      LibraryView.swift         Library tab — artist groups, search, selection, expand/collapse
      LibraryManager.swift      Library scanning, grouping, duplicate detection, subfolder tracking
      DriveView.swift           Drive tab — drive contents, sync status, game badges
      DriveManager.swift        External drive detection (removable, ejectable, non-internal)
      ImportManager.swift       Legacy import orchestration
      STFSPackage.swift         STFS header parsing, DTA extraction, RockBandGame enum
      MetadataEditorView.swift  Song info viewer sheet
      DuplicateResolverView.swift  Duplicate resolution UI
  RB3_TU4/                     Rock Band 3 Title Update 4
  rb3import.py                  Python CLI (RB3 only)
  README.md
```

---

## License

MIT. This project is not affiliated with or endorsed by Harmonix, MTV Games, or Microsoft.
