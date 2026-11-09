#!/usr/bin/env bash
# Install AlbumFrame (Google Photos shared-album slideshow) on a rooted Frameo frame.
# Run on your computer (macOS or Linux) with the frame connected over ADB.
#
#   ./install.sh                                  frame connected by USB or already 'adb connect'-ed
#   ./install.sh --device 192.168.1.50            connect over Wi-Fi first
#   ./install.sh --album https://photos.app.goo.gl/XXXX [--album ...]   set album link(s) on first install
#   ./install.sh --update                         only copy the latest slideshow files (no reboot)
#   ./install.sh --force                          skip the "is this the tested frame?" check
#
# See docs/2-install.md for what each step does.
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

DEVICE="" ; MODE=full ; FORCE=0 ; YES=0 ; ALBUMS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift ;;
    --album)  ALBUMS+=("$2"); shift ;;
    --update) MODE=update ;;
    --force)  FORCE=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "Unknown option $1 (see --help)" ;;
  esac
  shift
done

need curl ""
pick_device "$DEVICE"
check_root
say "Frame: $SERIAL ($($ADB shell getprop ro.product.manufacturer | tr -d '\r') $($ADB shell getprop ro.product.model | tr -d '\r'), Android SDK $($ADB shell getprop ro.build.version.sdk | tr -d '\r'))"

# ---- what this was tested on ----
SDK=$($ADB shell getprop ro.build.version.sdk | tr -d '\r')
ABI=$($ADB shell getprop ro.product.cpu.abi | tr -d '\r')
if [ "$SDK" != 27 ] || [ "$ABI" != armeabi-v7a ]; then
  [ $FORCE = 1 ] || die "Tested only on Android 8.1 (SDK 27) armeabi-v7a frames; this one is SDK $SDK $ABI. Use --force at your own risk."
  warn "Untested frame (SDK $SDK $ABI), continuing because of --force"
fi

# ---- downloads (cached in ./downloads, checked against known SHA-256) ----
DL="$ROOT/downloads"; mkdir -p "$DL"
fetch() {  # fetch <url> <file> <sha256 or ->
  local url="$1" out="$DL/$2" sum="$3"
  if [ ! -s "$out" ] || { [ "$sum" != - ] && [ "$(sha256 "$out")" != "$sum" ]; }; then
    say "Downloading $2"
    curl -fL --retry 3 -o "$out.part" "$url" || die "Download failed: $url"
    mv "$out.part" "$out"
  fi
  if [ "$sum" != - ] && [ "$(sha256 "$out")" != "$sum" ]; then rm -f "$out"; die "Checksum mismatch for $2"; fi
}

# static curl for the frame (the frame has no usable curl) + CA certificates
fetch https://github.com/stunnel/static-curl/releases/download/8.23.0-1/curl-linux-armv7-musl-8.23.0-1.tar.xz \
      curl-linux-armv7-musl-8.23.0-1.tar.xz 10245cccca6e81b654ec7454c0397ab26e4a31910440548625a3802ce0971b3b
fetch https://curl.se/ca/cacert.pem cacert.pem -
mkdir -p "$DL/curl" && tar -xJf "$DL/curl-linux-armv7-musl-8.23.0-1.tar.xz" -C "$DL/curl" curl

NEED_WV=0 ; NEED_IF=0
if [ $MODE = full ]; then
  # ImmichFrame: open-source frame app, used here as a full-screen browser for the slideshow
  fetch https://github.com/immichFrame/ImmichFrame_Android/releases/download/v51/ImmichFrame_v51.apk \
        ImmichFrame_v51.apk 3d4d93fc93aa92684c08a3802abbc55812e85eeed8b31300040d5b92d5bc4010
  $ADB shell pm list packages | tr -d '\r' | grep -q '^package:com.immichframe.immichframe$' || NEED_IF=1

  # WebView: the stock one (v61) is too old for the slideshow. 138 is the newest that runs on Android 8.
  WV=$($ADB shell dumpsys package com.android.webview | tr -d '\r' | sed -n 's/.*versionName=\([0-9]*\).*/\1/p' | head -1)
  if [ "${WV:-0}" -lt 100 ]; then
    NEED_WV=1
    WV_OID=b7268786318f404bdad53eaaec889619ff30100b935541a9e393e32efed3cf11
    if [ ! -s "$DL/webview138.apk" ] || [ "$(sha256 "$DL/webview138.apk")" != $WV_OID ]; then
      say "Finding WebView 138 (LineageOS prebuilt, ~90 MB)"
      HREF=$(curl -fsS -X POST -H 'Accept: application/vnd.git-lfs+json' -H 'Content-Type: application/vnd.git-lfs+json' \
        -d "{\"operation\":\"download\",\"transfers\":[\"basic\"],\"objects\":[{\"oid\":\"$WV_OID\",\"size\":90257078}]}" \
        https://review.lineageos.org/LineageOS/android_external_chromium-webview_prebuilt_arm.git/info/lfs/objects/batch \
        | sed -n 's/.*"href":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')
      [ -n "$HREF" ] || die "Could not get the WebView download link from review.lineageos.org"
      fetch "$HREF" webview138.apk $WV_OID
    fi
  else
    say "WebView is already version $WV, keeping it"
  fi
fi

# ---- confirm ----
if [ $MODE = full ] && [ $YES = 0 ]; then
  echo
  echo "This will:"
  echo "  - install ImmichFrame and make it the home screen (shows the slideshow)"
  [ $NEED_WV = 1 ] && echo "  - replace the system WebView 61 with 138 (original kept on the frame for uninstall)"
  echo "  - install the AlbumFrame slideshow in /data/albumframe and a boot service in /system/etc/init"
  echo "  - disable the Frameo app and the vendor auto-updaters (Adups FOTA, Rockchip update)"
  echo "  - block Gboard's internet access, keep ADB over Wi-Fi on port 5555"
  echo "  - restart the frame"
  echo
  echo "Make a backup first if you have not: ./scripts/backup.sh  (see docs/2-install.md)"
  read -r -p "Continue? [y/N] " a
  case "$a" in y|Y|yes) ;; *) die "Cancelled" ;; esac
fi

# ---- push ----
say "Copying files to the frame"
$ADB shell rm -rf $STAGE
$ADB shell mkdir -p $STAGE/frame $STAGE/bin
$ADB push "$ROOT"/frame/* $STAGE/frame/ >/dev/null
$ADB push "$ROOT/scripts/device-install.sh" $STAGE/ >/dev/null
$ADB push "$DL/curl/curl" "$DL/cacert.pem" $STAGE/bin/ >/dev/null
[ $NEED_WV = 1 ] && $ADB push "$DL/webview138.apk" $STAGE/bin/webview.apk >/dev/null
if [ ${#ALBUMS[@]} -gt 0 ]; then
  cfg='{"albums":['; sep=""
  for a in "${ALBUMS[@]}"; do cfg="$cfg$sep\"${a//\"/}\""; sep=","; done
  printf '%s]}\n' "$cfg" > "$DL/config.json"
  $ADB push "$DL/config.json" $STAGE/config.json >/dev/null
fi

if [ $MODE = full ]; then
  say "Installing ImmichFrame"
  $ADB install -r "$DL/ImmichFrame_v51.apk" >/dev/null || die "ImmichFrame install failed"
fi

OUT=$(rsh sh $STAGE/device-install.sh $STAGE $MODE | tr -d '\r'); echo "$OUT"
echo "$OUT" | grep -q 'ERROR' && die "Install stopped on the frame (see the message above). Nothing was rebooted."
if [ ${#ALBUMS[@]} -gt 0 ] && echo "$OUT" | grep -q 'kept existing settings'; then
  warn "The frame already had settings, so --album was not applied. Add the album in Frame settings instead."
fi
$ADB shell rm -rf $STAGE

if [ $MODE = update ]; then
  say "Updated. The slideshow restarts in a few seconds."
  exit 0
fi

say "Letting Android save the changes (20 s) before restarting"
sleep 20
$ADB reboot || true
sleep 15
wait_for_boot || die "The frame did not come back on ADB. Check it on screen; see docs/troubleshooting.md"

IP=$($ADB shell ip -4 addr show wlan0 2>/dev/null | tr -d '\r' | sed -n 's/.*inet \([0-9.]*\).*/\1/p')
echo
say "Installed."
echo "  Frame IP: ${IP:-unknown}   (ADB over Wi-Fi: adb connect ${IP:-<ip>}:5555)"
echo "  Next: add your Google Photos album link. See docs/3-google-photos-album.md"
echo "  On the frame: tap the screen -> Frame settings -> Photo albums -> + Add album"
