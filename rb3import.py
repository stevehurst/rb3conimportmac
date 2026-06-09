#!/usr/bin/env python3
"""Import .rb3con (STFS CON/LIVE) packages onto an Xbox 360 USB drive for Rock Band 3."""

import argparse
import hashlib
import os
import struct
import subprocess
import sys

STFS_MAGIC = {b"CON ", b"LIVE", b"PIRS"}
RB3_TITLE_ID = 0x45410914
CONTENT_TYPE_OFFSET = 0x344
TITLE_ID_OFFSET = 0x360
DISPLAY_NAME_OFFSET = 0x411
DISPLAY_NAME_MAX_BYTES = 128
MAX_FILENAME_LEN = 42

CONTENT_TYPE_SAVED_GAME = 0x00000001
CONTENT_TYPE_MARKETPLACE = 0x00000002
CONTENT_TYPE_INSTALLER = 0x000B0000

FOLDER_FOR_TYPE = {
    CONTENT_TYPE_SAVED_GAME: "00000001",
    CONTENT_TYPE_MARKETPLACE: "00000002",
    CONTENT_TYPE_INSTALLER: "000B0000",
}

PROFILE_DIR = "0000000000000000"
TITLE_ID_HEX = "45410914"
CONTENT_CACHE_REL = os.path.join("Content", PROFILE_DIR, "FFFE07DF", "00040000", "ContentCache.pkg")


def read_stfs_header(path):
    with open(path, "rb") as f:
        magic = f.read(4)
        if magic not in STFS_MAGIC:
            return None

        f.seek(CONTENT_TYPE_OFFSET)
        content_type = struct.unpack(">I", f.read(4))[0]

        f.seek(TITLE_ID_OFFSET)
        title_id = struct.unpack(">I", f.read(4))[0]

        f.seek(DISPLAY_NAME_OFFSET)
        raw_name = f.read(DISPLAY_NAME_MAX_BYTES)
        display_name = raw_name.decode("utf-16-be", errors="replace").split("\x00")[0].strip()

    return {
        "magic": magic.decode("ascii").strip(),
        "content_type": content_type,
        "title_id": title_id,
        "display_name": display_name or os.path.basename(path),
    }


def shorten_filename(name):
    if len(name) > MAX_FILENAME_LEN:
        return name[:MAX_FILENAME_LEN]
    return name


def find_rb3con_files(source_dir):
    files = []
    for name in sorted(os.listdir(source_dir)):
        full = os.path.join(source_dir, name)
        if not os.path.isfile(full):
            continue
        with open(full, "rb") as f:
            magic = f.read(4)
        if magic in STFS_MAGIC:
            files.append(full)
    return files


def cleanup_apple_double(directory):
    removed = 0
    for name in os.listdir(directory):
        if name.startswith("._"):
            path = os.path.join(directory, name)
            os.remove(path)
            removed += 1
    if removed:
        print(f"  Cleaned up {removed} macOS AppleDouble (._) file(s)")
    subprocess.run(["dot_clean", "-m", directory], capture_output=True)


def main():
    parser = argparse.ArgumentParser(description="Import RB3 custom songs onto Xbox 360 USB drive")
    parser.add_argument("source", help="Folder containing .rb3con files")
    parser.add_argument("drive", help="Mount point of Xbox 360 USB drive (e.g. /Volumes/128 THUMB)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without copying")
    parser.add_argument("--clean", action="store_true", help="Remove incorrectly placed files from previous runs")
    args = parser.parse_args()

    if not os.path.isdir(args.source):
        sys.exit(f"Error: source folder not found: {args.source}")
    if not os.path.isdir(args.drive):
        sys.exit(f"Error: drive not found: {args.drive}")

    if args.clean:
        clean_bad_files(args.drive, args.source, args.dry_run)

    songs = find_rb3con_files(args.source)
    if not songs:
        sys.exit(f"No STFS packages found in {args.source}")

    print(f"\nFound {len(songs)} STFS package(s) in {args.source}\n")
    print(f"{'Display Name':<40} {'Type':<5} {'CT':<10} {'Dest Filename':<44} {'Status'}")
    print("-" * 145)

    dest_dirs_used = set()
    copied = 0
    skipped = 0
    errors = 0

    for path in songs:
        basename = os.path.basename(path)
        header = read_stfs_header(path)
        if header is None:
            print(f"{'(invalid)':<40} {'???':<5} {'???':<10} {basename:<44} SKIP: not a valid STFS package")
            errors += 1
            continue

        if header["title_id"] != RB3_TITLE_ID:
            tid = format(header["title_id"], "08X")
            print(f"{header['display_name']:<40} {header['magic']:<5} {tid:<10} {basename:<44} SKIP: wrong title ID")
            skipped += 1
            continue

        ct = header["content_type"]
        ct_folder = FOLDER_FOR_TYPE.get(ct)
        if ct_folder is None:
            print(f"{header['display_name']:<40} {header['magic']:<5} {ct:08X}  {basename:<44} SKIP: unknown content type")
            skipped += 1
            continue

        dest_dir = os.path.join(args.drive, "Content", PROFILE_DIR, TITLE_ID_HEX, ct_folder)
        dest_dirs_used.add(dest_dir)

        filename = shorten_filename(basename)
        dest_path = os.path.join(dest_dir, filename)

        ct_label = {CONTENT_TYPE_SAVED_GAME: "SavedGame", CONTENT_TYPE_MARKETPLACE: "DLC", CONTENT_TYPE_INSTALLER: "TU"}.get(ct, f"{ct:08X}")

        if not os.path.isdir(dest_dir):
            if not args.dry_run:
                os.makedirs(dest_dir, exist_ok=True)

        if os.path.exists(dest_path):
            existing_size = os.path.getsize(dest_path)
            source_size = os.path.getsize(path)
            if existing_size == source_size:
                print(f"{header['display_name']:<40} {header['magic']:<5} {ct_label:<10} {filename:<44} SKIP: already exists")
                skipped += 1
                continue

        if args.dry_run:
            print(f"{header['display_name']:<40} {header['magic']:<5} {ct_label:<10} {filename:<44} [dry-run] would copy")
            copied += 1
        else:
            try:
                with open(path, "rb") as src:
                    data = src.read()
                with open(dest_path, "wb") as dst:
                    dst.write(data)
                dst_hash = hashlib.sha1(open(dest_path, "rb").read()).hexdigest()
                src_hash = hashlib.sha1(data).hexdigest()
                if src_hash != dst_hash:
                    print(f"{header['display_name']:<40} {header['magic']:<5} {ct_label:<10} {filename:<44} ERROR: hash mismatch!")
                    errors += 1
                    continue
                print(f"{header['display_name']:<40} {header['magic']:<5} {ct_label:<10} {filename:<44} COPIED (verified)")
                copied += 1
            except OSError as e:
                print(f"{header['display_name']:<40} {header['magic']:<5} {ct_label:<10} {filename:<44} ERROR: {e}")
                errors += 1

    print(f"\n{'Copied' if not args.dry_run else 'Would copy'}: {copied}  Skipped: {skipped}  Errors: {errors}")

    if not args.dry_run:
        for d in dest_dirs_used:
            cleanup_apple_double(d)

    cache_path = os.path.join(args.drive, CONTENT_CACHE_REL)
    if os.path.exists(cache_path):
        if args.dry_run:
            print(f"\n[dry-run] Would delete ContentCache.pkg")
        else:
            os.remove(cache_path)
            print(f"\nDeleted ContentCache.pkg (Xbox will rebuild on next boot)")
    else:
        print(f"\nContentCache.pkg already absent — Xbox will rebuild on next boot")

    if not args.dry_run and copied > 0:
        print(f"\nDone! Eject the drive safely before plugging into your Xbox 360.")


def clean_bad_files(drive, source_dir, dry_run):
    """Remove files from 00000002 that were incorrectly placed there by a previous run."""
    bad_dir = os.path.join(drive, "Content", PROFILE_DIR, TITLE_ID_HEX, "00000002")
    if not os.path.isdir(bad_dir):
        return

    source_names = set()
    for name in os.listdir(source_dir):
        full = os.path.join(source_dir, name)
        if not os.path.isfile(full):
            continue
        with open(full, "rb") as f:
            magic = f.read(4)
        if magic in STFS_MAGIC:
            source_names.add(name)

    removed = 0
    for name in os.listdir(bad_dir):
        filepath = os.path.join(bad_dir, name)
        if not os.path.isfile(filepath):
            continue
        if name.startswith("._"):
            continue
        with open(filepath, "rb") as f:
            magic = f.read(4)
        if magic != b"CON ":
            continue
        header = read_stfs_header(filepath)
        if header and header["content_type"] == CONTENT_TYPE_SAVED_GAME:
            if dry_run:
                print(f"[dry-run] Would remove misplaced CON from 00000002: {name}")
            else:
                os.remove(filepath)
                print(f"Removed misplaced CON from 00000002: {name}")
            removed += 1

    if removed:
        cleanup_apple_double(bad_dir)
        print(f"Cleaned {removed} misplaced file(s) from 00000002/")
    else:
        print("No misplaced files found in 00000002/")


if __name__ == "__main__":
    main()
