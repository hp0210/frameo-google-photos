#!/usr/bin/env bash
# Remove AlbumFrame and give the frame back to the Frameo app.
#   ./uninstall.sh [--device <ip>] [--restore-webview] [--keep-immichframe]
# --restore-webview puts the original WebView 61 back (the new one works fine with Frameo too).
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
DEVICE=""; RWV=""; KEEPIF=0
while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift ;;
    --restore-webview) RWV=restore-webview ;;
    --keep-immichframe) KEEPIF=1 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) die "Unknown option $1" ;;
  esac; shift
done
pick_device "$DEVICE"
check_root
read -r -p "Remove AlbumFrame from $SERIAL and switch back to Frameo? [y/N] " a
case "$a" in y|Y|yes) ;; *) die "Cancelled" ;; esac
$ADB shell mkdir -p $STAGE
$ADB push "$ROOT/scripts/device-uninstall.sh" $STAGE/ >/dev/null
rsh sh $STAGE/device-uninstall.sh $RWV | tr -d '\r'
$ADB shell rm -rf $STAGE
[ $KEEPIF = 1 ] || { $ADB uninstall com.immichframe.immichframe >/dev/null && say "ImmichFrame removed"; }
say "Letting Android save the changes (20 s), then restarting"
sleep 20
$ADB reboot || true
say "Done. The frame starts in Frameo. ADB over Wi-Fi stays on until you turn it off in Frameo's settings."
