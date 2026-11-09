#!/system/bin/sh
# (Re)start the AlbumFrame web server in the right mode:
#   config "remote":true  -> listen on the home network (port 8080) so settings can be edited from a phone/computer
#   otherwise             -> frame only (127.0.0.1:8080)
# Power/screen actions are always refused unless the request comes from the frame itself (see ctl.cgi).
D=/data/albumframe
BB=/system/bin/busybox
BIND=127.0.0.1:8080
$BB tr -d '\n ' < $D/config.json 2>/dev/null | $BB grep -q '"remote":true' && BIND=8080
cur=$(ps -A -o ARGS 2>/dev/null | $BB grep "busybox httpd -p" | $BB grep -v grep | $BB head -1)
case "$cur" in *"httpd -p $BIND -h"*) exit 0 ;; esac
$BB pkill -f "busybox httpd -p" 2>/dev/null
sleep 1
$BB httpd -p $BIND -h $D/www
echo "$(date '+%F %T') web server on $BIND" >> $D/ctl.log
