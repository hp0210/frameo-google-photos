#!/system/bin/sh
# AlbumFrame firewall: block internet access for apps that don't need it (local network still allowed).
# Run at boot from run.sh. Safe to re-run (rebuilds its own chain). Undo: sh firewall.sh off
BLOCK="com.google.android.inputmethod.latin"     # Gboard keyboard: analytics, feature flags, pack downloads
CH=albumframe_block

for IPT in iptables ip6tables; do
  $IPT -w -D OUTPUT -j $CH 2>/dev/null
  $IPT -w -F $CH 2>/dev/null
  $IPT -w -X $CH 2>/dev/null
done
[ "$1" = "off" ] && { echo "firewall removed"; exit 0; }

for IPT in iptables ip6tables; do
  $IPT -w -N $CH
  $IPT -w -I OUTPUT 1 -j $CH
done
for P in $BLOCK; do
  U=$(stat -c %u /data/data/$P 2>/dev/null)
  [ -n "$U" ] || continue
  # allow the home network, reject everything else for this app
  iptables  -w -A $CH -m owner --uid-owner $U -d 127.0.0.0/8    -j RETURN
  iptables  -w -A $CH -m owner --uid-owner $U -d 192.168.0.0/16 -j RETURN
  iptables  -w -A $CH -m owner --uid-owner $U -d 10.0.0.0/8     -j RETURN
  iptables  -w -A $CH -m owner --uid-owner $U -d 172.16.0.0/12  -j RETURN
  iptables  -w -A $CH -m owner --uid-owner $U -j REJECT
  ip6tables -w -A $CH -m owner --uid-owner $U -d ::1/128   -j RETURN
  ip6tables -w -A $CH -m owner --uid-owner $U -d fe80::/10 -j RETURN
  ip6tables -w -A $CH -m owner --uid-owner $U -d fc00::/7  -j RETURN
  ip6tables -w -A $CH -m owner --uid-owner $U -j REJECT
  echo "blocked internet for $P (uid $U)"
done
