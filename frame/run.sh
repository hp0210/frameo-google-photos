#!/system/bin/sh
# Started at boot by /system/etc/init/albumframe.rc
D=/data/albumframe
W=$D/www
BB=/system/bin/busybox
# firewall first: block internet for apps that don't need it (Gboard)
sh $D/firewall.sh >> $D/ctl.log 2>&1
mkdir -p $W/cgi-bin
cp -f $D/index.html $D/settings.html $D/defaults.js $W/ 2>/dev/null
cp -f $D/ctl.cgi $W/cgi-bin/ctl && chmod 755 $W/cgi-bin/ctl
# web server: slideshow + settings (frame only, or home network if "remote" is on in settings)
sh $D/web.sh
# two-finger-hold "back to slideshow" gesture
$BB pkill -f "$D/gesture.sh" 2>/dev/null
$BB setsid sh $D/gesture.sh >/dev/null 2>&1 < /dev/null &
# wait for network, then refresh album links every N minutes (config "refreshMin", default 30)
sleep 30
while true; do
  sh $D/sync.sh
  m=$($BB tr -d '\n ' < $D/config.json 2>/dev/null | $BB grep -o '"refreshMin":[0-9]*' | $BB grep -o '[0-9]*$')
  [ -n "$m" ] && [ "$m" -ge 5 ] || m=30
  sleep $((m*60))
done
