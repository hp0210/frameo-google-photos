#!/usr/bin/env bash
# Catch the frame on USB while it boots, then switch ADB to Wi-Fi.
# Use this when the frame keeps turning off on USB power (see docs/1-enable-adb.md):
# it only needs a few seconds of USB connection.
#   ./scripts/catch-usb.sh
set -uo pipefail
source "$(dirname "$0")/lib.sh"
need adb "Install Android platform-tools first."
say "Waiting for the frame on USB... plug it in / turn it on now (Ctrl+C to stop)"
while true; do
  line=$(adb devices | awk 'NR>1 && NF==2 && $1 !~ /:/ {print $1, $2; exit}')
  if [ -n "$line" ]; then
    s=${line% *}; st=${line#* }
    case "$st" in
      device)
        say "Found $s, turning on ADB over Wi-Fi (port 5555)"
        adb -s "$s" tcpip 5555 || { sleep 1; continue; }
        sleep 3
        ip=$(adb -s "$s" shell ip -4 addr show wlan0 2>/dev/null | tr -d '\r' | sed -n 's/.*inet \([0-9.]*\).*/\1/p')
        adb -s "$s" shell su 0 setprop persist.adb.tcp.port 5555 2>/dev/null || true
        say "Done. Frame IP: ${ip:-unknown (connect it to Wi-Fi first)}"
        [ -n "$ip" ] && echo "Now unplug from the computer, power it normally, and run: adb connect $ip:5555"
        exit 0 ;;
      unauthorized) printf '\r  Tap "Allow" on the frame (tick "Always allow from this computer")...' ;;
    esac
  fi
  sleep 0.5
done
