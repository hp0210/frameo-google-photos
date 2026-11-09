#!/usr/bin/env bash
# Back up the frame BEFORE installing: copies every partition except userdata to your computer.
# Read-only on the frame's partitions (dd reads them; nothing is written to any partition).
#   ./scripts/backup.sh [--device <ip>] [--out <folder>] [partition-name ...]
# Default output: ./backup-<serial>-<date>/   (~3.5 GB, takes 10-20 minutes over Wi-Fi)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
DEVICE=""; OUT=""; PARTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift ;;
    --out) OUT="$2"; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) PARTS+=("$1") ;;
  esac; shift
done
pick_device "$DEVICE"
check_root
OUT=${OUT:-"$ROOT/backup-$(echo "$SERIAL" | tr ':.' '__')-$(date +%Y%m%d-%H%M)"}
mkdir -p "$OUT"
say "Backing up to $OUT"

# partition names from /dev/block/by-name (skip userdata: it is your Frameo photos/settings and is huge)
if [ ${#PARTS[@]} = 0 ]; then
  PARTS=($(rsh ls /dev/block/by-name | tr -d '\r' | grep -v '^userdata$'))
fi
rsh ls -l /dev/block/by-name/ | tr -d '\r' > "$OUT/by-name.txt"
$ADB shell getprop | tr -d '\r' > "$OUT/getprop.txt"
$ADB shell pm list packages -f | tr -d '\r' > "$OUT/packages.txt"

: > "$OUT/SHA256SUMS"
TMP=/sdcard/albumframe-backup-tmp      # temporary copy on the frame, removed file by file after a verified pull
rsh mkdir -p $TMP
for p in "${PARTS[@]}"; do
  [ -n "$p" ] || continue
  say "  $p"
  rsh dd if=/dev/block/by-name/$p of=$TMP/$p.img bs=1048576 2>/dev/null
  dev=$(rsh sha256sum /dev/block/by-name/$p | tr -d '\r' | cut -d' ' -f1)
  $ADB pull $TMP/$p.img "$OUT/$p.img" >/dev/null
  got=$(sha256 "$OUT/$p.img")
  [ "$dev" = "$got" ] || die "Checksum mismatch for $p (frame $dev, copy $got). Run the backup again."
  rsh rm -f $TMP/$p.img
  echo "$got  $p.img" >> "$OUT/SHA256SUMS"
done

# Frameo app data (pairing, friends list) and the original WebView, for an easy undo
if rsh test -d /data/data/net.frameo.frame; then
  rsh tar -czf $TMP/frameo_data.tgz /data/data/net.frameo.frame 2>/dev/null
  $ADB pull $TMP/frameo_data.tgz "$OUT/" >/dev/null && rsh rm -f $TMP/frameo_data.tgz
fi
$ADB pull /system/app/webview/webview.apk "$OUT/webview_original.apk" >/dev/null 2>&1 || true
rsh rmdir $TMP 2>/dev/null || true

say "Backup done: $OUT"
echo "Keep this folder somewhere safe. It is NOT meant for git (it is in .gitignore)."
