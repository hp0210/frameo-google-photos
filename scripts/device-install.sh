#!/system/bin/sh
# Runs ON the frame as root. Pushed and started by install.sh. Do not run on your computer.
#   sh device-install.sh <staging-dir> full     first install / reinstall (needs a reboot afterwards)
#   sh device-install.sh <staging-dir> update   copy new slideshow files and restart it (no reboot)
# Never writes to any partition other than /system (2-3 files) and /data.
S=${1:-/data/local/tmp/albumframe-install}
MODE=${2:-full}
D=/data/albumframe                 # everything AlbumFrame uses lives here
KEEP=/data/albumframe-original     # originals kept so uninstall can put them back
BB=/system/bin/busybox
P=com.immichframe.immichframe
fail() { echo "[frame] ERROR: $*"; exit 1; }
log()  { echo "[frame] $*"; }

[ "$(id -u)" = 0 ] || fail "must run as root"
[ -x $BB ] && $BB --list | grep -q '^httpd$' || fail "$BB with httpd is missing (this firmware is different from the tested one)"
mkdir -p $D/www/cgi-bin $D/tmp $KEEP

# ---- 1. AlbumFrame files ----
for f in run.sh sync.sh web.sh firewall.sh gesture.sh ctl.cgi index.html settings.html defaults.js; do
  cp -f $S/frame/$f $D/$f || fail "copy $f"
done
if [ -f $S/bin/curl ]; then cp -f $S/bin/curl $D/curl; cp -f $S/bin/cacert.pem $D/cacert.pem; fi
[ -x $D/curl ] || chmod 755 $D/curl 2>/dev/null
[ -s $D/curl ] || fail "curl missing"
if [ ! -s $D/config.json ]; then
  if [ -s $S/config.json ]; then cp $S/config.json $D/config.json; else echo '{"albums":[]}' > $D/config.json; fi
  log "created settings file"
else
  log "kept existing settings ($D/config.json)"
fi
chmod 755 $D/*.sh $D/ctl.cgi $D/curl
chmod 644 $D/*.html $D/*.js $D/cacert.pem $D/config.json
log "AlbumFrame files installed in $D"

if [ "$MODE" = update ]; then
  stop albumframe 2>/dev/null; sleep 1; start albumframe
  am force-stop $P; sleep 1; input keyevent KEYCODE_HOME    # reload the slideshow page
  log "slideshow service restarted"
  exit 0
fi

# ---- 2. /system: WebView, boot service, DNS file for curl ----
mount -o remount,rw /system || fail "cannot remount /system read-write"
WV=/system/app/webview/webview.apk
if [ -f $S/bin/webview.apk ]; then
  [ -f $WV ] || { mount -o remount,ro /system; fail "$WV not found (different firmware?)"; }
  [ -f $KEEP/webview.apk ] || cp $WV $KEEP/webview.apk
  cp -f $S/bin/webview.apk $WV && chmod 644 $WV && chcon u:object_r:system_file:s0 $WV
  rm -rf /system/app/webview/oat
  log "WebView replaced (original saved in $KEEP)"
fi
cp -f $S/frame/albumframe.rc /system/etc/init/albumframe.rc
chmod 644 /system/etc/init/albumframe.rc; chcon u:object_r:system_file:s0 /system/etc/init/albumframe.rc
if [ ! -f /system/etc/resolv.conf ]; then
  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /system/etc/resolv.conf
  chmod 644 /system/etc/resolv.conf; chcon u:object_r:system_file:s0 /system/etc/resolv.conf
  touch $KEEP/resolv.conf.created
fi
sync; mount -o remount,ro /system
log "boot service installed"

# ---- 3. ImmichFrame: full-screen browser showing the slideshow ----
DD=/data/data/$P
[ -d $DD ] || fail "ImmichFrame is not installed"
am force-stop $P
U=$(stat -c %u $DD)
mkdir -p $DD/shared_prefs && chown $U:$U $DD/shared_prefs && chmod 771 $DD/shared_prefs
F=$DD/shared_prefs/${P}_preferences.xml
cat > $F <<'EOF'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="authSecret"></string>
    <boolean name="blurredBackground" value="false" />
    <boolean name="activeTimes" value="false" />
    <boolean name="useWebView" value="true" />
    <boolean name="settingsLock" value="true" />
    <boolean name="showCurrentDate" value="false" />
    <string name="webview_url">http://127.0.0.1:8080/index.html</string>
</map>
EOF
chown $U:$U $F && chmod 660 $F && restorecon -R $DD/shared_prefs
log "ImmichFrame set to show the slideshow"

# ---- 4. home screen, Frameo and vendor updaters off, Wi-Fi ADB on ----
cmd package set-home-activity $P/.MainActivity >/dev/null && log "ImmichFrame is now the home screen"
for p in net.frameo.frame com.adups.fota android.rockchip.update.service; do
  pm list packages | grep -q "^package:$p\$" && pm disable-user --user 0 $p >/dev/null && log "disabled $p"
done
setprop persist.adb.tcp.port 5555
sync
log "done. Wait ~20 s before rebooting so Android saves the app changes."
