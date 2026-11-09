#!/system/bin/sh
# Runs ON the frame as root. Pushed and started by uninstall.sh. Puts the frame back to Frameo.
#   sh device-uninstall.sh [restore-webview]
D=/data/albumframe
KEEP=/data/albumframe-original
BB=/system/bin/busybox
log() { echo "[frame] $*"; }

stop albumframe 2>/dev/null
[ -f $D/firewall.sh ] && sh $D/firewall.sh off
$BB pkill -f "busybox httpd -p" 2>/dev/null
$BB pkill -f "$D/gesture.sh" 2>/dev/null
$BB pkill -f "$D/sync.sh" 2>/dev/null

mount -o remount,rw /system
rm -f /system/etc/init/albumframe.rc
[ -f $KEEP/resolv.conf.created ] && rm -f /system/etc/resolv.conf
if [ "$1" = restore-webview ] && [ -f $KEEP/webview.apk ]; then
  cp -f $KEEP/webview.apk /system/app/webview/webview.apk
  chmod 644 /system/app/webview/webview.apk; chcon u:object_r:system_file:s0 /system/app/webview/webview.apk
  rm -rf /system/app/webview/oat
  log "original WebView restored"
fi
sync; mount -o remount,ro /system

for p in net.frameo.frame com.adups.fota android.rockchip.update.service; do
  pm list packages -d | grep -q "^package:$p\$" && pm enable $p >/dev/null && log "enabled $p"
done
H=$(cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | grep '^ *net.frameo.frame/' | head -1 | tr -d ' ')
[ -n "$H" ] || H=net.frameo.frame/.ui.activities.AWaitForDeferredInitCompleted   # Frameo 1.32 home screen
[ -n "$H" ] && cmd package set-home-activity "$H" >/dev/null && log "Frameo is the home screen again ($H)"

# only our own folders (fixed paths)
rm -rf /data/albumframe
[ "$1" = restore-webview ] && rm -rf /data/albumframe-original
sync
log "done"
