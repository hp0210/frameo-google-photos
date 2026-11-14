#!/system/bin/sh
# AlbumFrame control endpoint.
#   from the frame itself (127.0.0.1): everything
#   from other devices on the LAN:     getcfg, setcfg, sync, status, log only (no power / screen actions)
# /cgi-bin/ctl?a=reboot|off|wifi|settings|bright&v=0..255|bl&v=N|light&v=0|1|status|getcfg|setcfg(POST json)|sync|log|exif&id=<photo id>
D=/data/albumframe
CFG=$D/config.json
BB=/system/bin/busybox
# camera info: the first 64 KB of a photo's original file (holds the EXIF), for index.html to read.
# Google doesn't allow the page to fetch it directly (no CORS). Only Google Photos ids, only from the frame itself.
case "$QUERY_STRING" in a=exif\&id=*)
  id="${QUERY_STRING#a=exif&id=}"
  case "$REMOTE_ADDR" in 127.0.0.1|::1|::ffff:127.0.0.1) ;; *) id="" ;; esac
  case "$id" in ""|*[!A-Za-z0-9_-]*) echo "Status: 400 Bad Request"; echo; exit 0 ;; esac
  echo "Content-Type: application/octet-stream"; echo "Cache-Control: max-age=86400"; echo
  exec $D/curl -sS -L --cacert $D/cacert.pem --connect-timeout 15 --max-time 30 -r 0-65535 \
    "https://lh3.googleusercontent.com/pw/$id=d" 2>/dev/null ;;
esac
echo "Content-Type: application/json"
echo "Cache-Control: no-store"
echo "Access-Control-Allow-Origin: *"
echo
q="$QUERY_STRING"
a=""; v=""
for kv in $(echo "$q" | tr '&' ' '); do
  case "$kv" in a=*) a="${kv#a=}" ;; v=*) v="${kv#v=}" ;; esac
done
case "$v" in *[!0-9]*) v="" ;; esac
# fast path for the brightness slider while dragging: set the backlight directly (Android's "settings" takes ~0.7 s)
if [ "$a" = bl ]; then
  case "$REMOTE_ADDR" in 127.0.0.1|::1|::ffff:127.0.0.1) ;; *) echo '{"ok":false}'; exit 0 ;; esac
  B=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
  [ -n "$B" ] && [ -n "$v" ] && { [ "$v" -lt 20 ] && v=20; [ "$v" -gt 255 ] && v=255; echo "$v" > $B/brightness; }   # Android's floor is 20
  echo '{"ok":true}'; exit 0
fi
LOG=$D/ctl.log
[ -f $LOG ] && [ $($BB wc -c < $LOG) -gt 100000 ] && mv $LOG $LOG.1
echo "$(date '+%F %T') ${REMOTE_ADDR:-?} $a $v" >> $LOG

local_only() {
  case "$REMOTE_ADDR" in 127.0.0.1|::1|::ffff:127.0.0.1) return 0 ;; esac
  echo '{"ok":false,"err":"only allowed on the frame itself"}'; exit 0
}

case "$a" in
  reboot)   local_only; echo '{"ok":true}'; (sleep 1; sync; svc power reboot || reboot) >/dev/null 2>&1 & ;;
  off)      local_only; echo '{"ok":true}'; (sleep 1; sync; svc power shutdown || reboot -p) >/dev/null 2>&1 & ;;
  wifi)     local_only; echo '{"ok":true}'; am start -a android.settings.WIFI_SETTINGS >/dev/null 2>&1 & ;;
  settings) local_only; echo '{"ok":true}'; am start -a android.settings.SETTINGS >/dev/null 2>&1 & ;;
  bright)   local_only
            [ -n "$v" ] && [ "$v" -le 255 ] && { settings put system screen_brightness_mode 0; settings put system screen_brightness "$v"; }
            echo "{\"ok\":true,\"v\":$(settings get system screen_brightness)}" ;;
  light)    # night mode: v=0 switches the backlight fully off (Android's lowest brightness still glows), v=1 back on
            local_only
            B=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
            if [ -z "$B" ]; then echo '{"ok":false,"err":"no backlight control"}'
            elif [ "$v" = 0 ]; then
              cur=$(cat $B/brightness); [ "$cur" -gt 0 ] && echo "$cur" > $D/tmp/backlight
              # after the brightness change night mode just asked Android for, so Android doesn't turn it back on
              ($BB setsid sh -c "sleep 2; echo 0 > $B/brightness" >/dev/null 2>&1 < /dev/null &)
              echo '{"ok":true}'
            else
              old=$(cat $D/tmp/backlight 2>/dev/null); [ -n "$old" ] && [ "$old" -gt 0 ] || old=$(settings get system screen_brightness)
              [ "$(cat $B/brightness)" = 0 ] && echo "$old" > $B/brightness
              echo '{"ok":true}'
            fi ;;
  getcfg)   if [ -s $CFG ]; then cat $CFG; else echo '{}'; fi ;;
  setcfg)   # body = JSON settings from settings.html (max 64 KB)
            n=${CONTENT_LENGTH:-0}
            if [ "$n" -gt 0 ] && [ "$n" -lt 65536 ]; then
              $BB head -c "$n" > $CFG.tmp
              if $BB head -c 1 $CFG.tmp | $BB grep -q '{'; then
                cp -f $CFG $CFG.bak 2>/dev/null; mv $CFG.tmp $CFG; chmod 644 $CFG
                echo '{"ok":true}'
                # switch web server mode if the remote setting changed (after this reply is sent)
                ($BB setsid sh -c "sleep 2; sh $D/web.sh" >/dev/null 2>&1 < /dev/null &)
              else rm -f $CFG.tmp; echo '{"ok":false,"err":"bad json"}'; fi
            else echo '{"ok":false,"err":"empty"}'; fi ;;
  sync)     if pgrep -f "$D/sync.sh" >/dev/null; then echo '{"ok":true,"running":true}'
            else echo '{"ok":true}'; ($BB setsid sh $D/sync.sh >/dev/null 2>&1 &) ; fi ;;
  status)   ip=$(ip -4 addr show wlan0 2>/dev/null | sed -n 's/.*inet \([0-9.]*\).*/\1/p')
            ssid=$(dumpsys wifi | sed -n 's/.*mWifiInfo SSID: \([^,]*\),.*/\1/p' | head -1)
            run=false; pgrep -f "$D/sync.sh" >/dev/null && run=true
            st='{}'; [ -s $D/www/status.json ] && st=$(cat $D/www/status.json)
            echo "{\"ok\":true,\"bright\":$(settings get system screen_brightness),\"ip\":\"$ip\",\"ssid\":\"$ssid\",\"syncing\":$run,\"sync\":$st}" ;;
  log)      echo '{"ok":true}' ;;
  *)        echo '{"ok":false}' ;;
esac
