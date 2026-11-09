#!/system/bin/sh
# AlbumFrame sync: refresh the list of photo links from one or more public Google Photos shared albums.
# Album links come from config.json ("albums":[...]); falls back to album_url.
# Runs on the frame as root. Needs /data/albumframe/{curl,cacert.pem}.
D=/data/albumframe
P=/data/albumframe/www
T=$D/tmp
BB=/system/bin/busybox
UA="Mozilla/5.0 (Linux; Android 8.1.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0 Safari/537.36"
CURL="$D/curl -sS -L --cacert $D/cacert.pem --connect-timeout 20 --max-time 120 -A"
LOG=$D/sync.log

log() { echo "$(date '+%F %T') $*" >> $LOG; }
mkdir -p $P $T
[ -f $LOG ] && [ $($BB wc -c < $LOG) -gt 200000 ] && mv $LOG $LOG.1

# album links: everything that looks like a Google Photos link inside the "albums" array of config.json
albums() {
  if [ -s $D/config.json ]; then
    $BB tr -d '\n' < $D/config.json | $BB grep -o '"albums" *: *\[[^]]*\]' \
      | $BB grep -oE 'https://(photos\.app\.goo\.gl|photos\.google\.com|goo\.gl)/[^" ,]+'
  fi
  [ -s $D/config.json ] || cat $D/album_url 2>/dev/null
}

# one line per item: "base_url capture_ms tz_offset_ms width height video_ms" (video_ms=0 for photos)
VIDAWK='/^\["AF1Qip/{ d=0; if (match($0, /"76647426":\[[0-9]+/)) d=substr($0, RSTART+12, RLENGTH-12); print "D" d " " $0 }'
ITEMPAT='s/^D\([0-9]*\) \["AF1Qip[^"]*",\["\(https:\/\/lh3\.googleusercontent\.com\/pw\/[A-Za-z0-9_-]*\)",\([0-9]*\),\([0-9]*\)[^"]*\],\([0-9]\{13\}\),"[^"]*",\(-\{0,1\}[0-9]*\),.*/\2 \5 \6 \3 \4 \1/p'
items() { $BB sed 's/\\"/"/g; s/\["\(AF1Qip[A-Za-z0-9_-]*",\["https:\/\/lh3\)/\
["\1/g' "$1" | $BB awk "$VIDAWK" | $BB sed -n "$ITEMPAT"; }

# fetch one album into $T/album.txt; sets TITLE; returns non-zero on failure
fetch_album() {
  LINK="$1"; : > $T/album.txt; TITLE=""
  EFF=$($CURL "$UA" -o $T/page.html -w '%{url_effective}' "$LINK") || { ERR="could not open link"; return 1; }
  AID=$(echo "$EFF" | $BB sed -n 's#.*/share/\([^?/]*\).*#\1#p')
  KEY=$(echo "$EFF" | $BB sed -n 's#.*[?&]key=\([^&]*\).*#\1#p')
  [ -n "$AID" ] && [ -n "$KEY" ] || { ERR="not a shared album link"; return 1; }
  TITLE=$($BB sed -n 's#.*<title>\([^<]*\) - Google Photos</title>.*#\1#p' $T/page.html | $BB head -1 | $BB tr -d '"\\')
  $BB sed -n "/key: 'ds:1'/,\$p" $T/page.html > $T/ds1.txt
  items $T/ds1.txt > $T/album.txt
  TOK=$($BB grep -oE '\}\]\],"[A-Za-z0-9_-]{20,}",\[' $T/ds1.txt | $BB head -1 | $BB sed 's/^}]],"//; s/",\[$//')
  n=1
  while [ -n "$TOK" ] && [ $n -lt 100 ]; do
    REQ="[[[\"snAcKc\",\"[\\\"$AID\\\",\\\"$TOK\\\",null,\\\"$KEY\\\"]\",null,\"generic\"]]]"
    $CURL "$UA" -o $T/batch.txt --data-urlencode "f.req=$REQ" \
      -H 'Content-Type: application/x-www-form-urlencoded;charset=UTF-8' \
      https://photos.google.com/_/PhotosUi/data/batchexecute || { ERR="page $n failed"; return 1; }
    items $T/batch.txt >> $T/album.txt
    TOK=$($BB grep -oE '\}\]\],\\"[A-Za-z0-9_-]{20,}\\",' $T/batch.txt | $BB head -1 | $BB sed 's/^}]],\\"//; s/\\",$//')
    n=$((n+1))
  done
  [ -s $T/album.txt ] || { ERR="album is empty or not public"; return 1; }
  return 0
}

albums | $BB awk '!s[$0]++' > $T/albums.txt
[ -s $T/albums.txt ] || { log "no album links configured"; echo '{"time":'$(date +%s)',"total":0,"albums":[]}' > $P/status.json; exit 1; }

: > $T/urls.txt; ST=""; OKCOUNT=0
while read -r LINK; do
  [ -z "$LINK" ] && continue
  ERR=""
  if fetch_album "$LINK"; then
    c=$($BB wc -l < $T/album.txt); OKCOUNT=$((OKCOUNT+1))
    cat $T/album.txt >> $T/urls.txt
    # keep last good copy per album, used if a later fetch fails
    k=$(echo -n "$LINK" | $BB md5sum | $BB cut -c1-12); cp $T/album.txt $T/last_$k.txt
    log "album ok: $c items \"$TITLE\" $LINK"
    ST="$ST{\"url\":\"$LINK\",\"title\":\"$TITLE\",\"count\":$c,\"ok\":true},"
  else
    k=$(echo -n "$LINK" | $BB md5sum | $BB cut -c1-12)
    [ -s $T/last_$k.txt ] && cat $T/last_$k.txt >> $T/urls.txt
    log "album FAILED ($ERR): $LINK"
    ST="$ST{\"url\":\"$LINK\",\"title\":\"$TITLE\",\"count\":0,\"ok\":false,\"err\":\"$ERR\"},"
  fi
done < $T/albums.txt

# de-dupe across albums, keep order
$BB awk '!s[$1]++' $T/urls.txt > $T/list.txt
COUNT=$($BB wc -l < $T/list.txt)
VIDS=$($BB awk '$6>0' $T/list.txt | $BB wc -l)
echo "{\"time\":$(date +%s),\"total\":$COUNT,\"videos\":$VIDS,\"albums\":[${ST%,}]}" > $P/status.json
[ "$COUNT" -gt 0 ] || { log "no photos found"; exit 1; }

# publish link list for the slideshow (photos load on demand), atomically
{ echo -n "window.PHOTOS=["; first=1
  while read -r U TS TZ W H V; do [ $first = 1 ] && first=0 || echo -n ","; echo -n "[\"$U\",$TS,$TZ,$W,$H,${V:-0}]"; done < $T/list.txt
  echo "];window.PHOTOS_UPDATED=$(date +%s);"; } > $P/photos.js.tmp && mv $P/photos.js.tmp $P/photos.js

log "ok: total=$COUNT videos=$VIDS albums=$OKCOUNT"
