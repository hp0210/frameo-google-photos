#!/system/bin/sh
# AlbumFrame gesture watcher: hold TWO fingers on the screen for 2 seconds
# from anywhere (Android settings, etc.) -> return to the slideshow.
# touchscreen: the input device that reports multi-touch slots (gslX680 = event2 on the NZ-DP1002)
D=""
for e in /sys/class/input/event*; do
  case "$(cat $e/device/name 2>/dev/null)" in *gsl*|*GSL*|*touch*|*Touch*|*ft5*|*goodix*) D=/dev/input/${e##*/}; break ;; esac
done
[ -n "$D" ] || D=/dev/input/event2
BB=/system/bin/busybox
HOLD=2                        # seconds
LOG=/data/albumframe/gesture.log

exec 3< $D
s0=0 s1=0 s2=0 s3=0 s4=0 s5=0 s6=0 s7=0 s8=0 s9=0
slot=0 fingers=0 t0=0 fired=0

count() { fingers=$((s0+s1+s2+s3+s4+s5+s6+s7+s8+s9)); }

while true; do
  if [ $fingers -ge 2 ]; then
    # fingers are down: poll with a timeout so a still hold is detected
    data=$($BB timeout -t 1 $BB dd bs=1600 count=1 <&3 2>/dev/null | $BB od -An -v -w16 -td2)
  else
    data=$($BB dd bs=1600 count=1 <&3 2>/dev/null | $BB od -An -v -w16 -td2)
  fi
  if [ -n "$data" ]; then
    while read -r a b c d type code vlo vhi; do
      [ -z "$type" ] && continue
      if [ "$type" = 3 ] && [ "$code" = 47 ]; then slot=$vlo
      elif [ "$type" = 3 ] && [ "$code" = 57 ]; then
        [ $slot -le 9 ] && { [ "$vlo" = -1 ] && eval s$slot=0 || eval s$slot=1; }
      elif [ "$type" = 1 ] && [ "$code" = 330 ] && [ "$vlo" = 0 ]; then
        s0=0 s1=0 s2=0 s3=0 s4=0 s5=0 s6=0 s7=0 s8=0 s9=0
      fi
    done <<EOF
$data
EOF
    prev=$fingers; count
    if [ $fingers -ge 2 ] && [ $prev -lt 2 ]; then t0=$(date +%s); fired=0; fi
    [ $fingers -lt 2 ] && fired=0
  fi
  if [ $fingers -ge 2 ] && [ $fired = 0 ] && [ $(( $(date +%s) - t0 )) -ge $HOLD ]; then
    fired=1
    echo "$(date '+%F %T') two-finger hold -> slideshow" >> $LOG
    input keyevent KEYCODE_HOME
  fi
done
