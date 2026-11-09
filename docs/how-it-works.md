# How it works

## On the frame

| Path | What |
|---|---|
| `/system/etc/init/albumframe.rc` | init service, root (`u:r:su:s0`), started when `sys.boot_completed=1`, runs `run.sh` |
| `/system/etc/resolv.conf` | DNS servers for the static curl (it reads this file; Android itself does not use it) |
| `/system/app/webview/webview.apk` | WebView 138 (original kept in `/data/albumframe-original/`) |
| `/data/albumframe/` | everything else: scripts, `config.json` (settings), logs, `www/` (served pages) |
| ImmichFrame prefs | `useWebView=true`, `webview_url=http://127.0.0.1:8080/index.html`, `settingsLock=true` |

`run.sh` runs, in order:
1. `firewall.sh` – iptables/ip6tables chain `albumframe_block`. Rejects internet traffic from the uids of the apps in `BLOCK=` (Gboard). LAN and loopback are allowed.
2. Copies the pages into `www/`, starts `web.sh` – busybox `httpd` with CGI. It listens on `127.0.0.1:8080`, or on all interfaces when `"remote":true`.
3. `gesture.sh` – reads the touchscreen's raw input events. Two or more fingers held for 2 s sends `KEYCODE_HOME`.
4. Loop: `sync.sh`, then sleep `refreshMin` minutes.

`www/cgi-bin/ctl` (`ctl.cgi`) is the small API used by the pages: `getcfg`, `setcfg` (POST), `status`, `sync`,
`bright`, `reboot`, `off`, `wifi`, `settings`. Power and screen actions are refused unless the request comes from `127.0.0.1`.

## Reading a shared album (`sync.sh`)

No Google account and no API. The script loads the public share page the way a browser does:

1. `curl` follows the `photos.app.goo.gl` link to `photos.google.com/share/<albumId>?key=<key>`.
2. The first ~300 items are in the page's `AF_initDataCallback({key: 'ds:1', …})` data.
3. More pages come from the `batchexecute` RPC `snAcKc` with `[albumId, pageToken, null, key]`.
4. Each item is cut out with sed/awk, giving: base URL `https://lh3.googleusercontent.com/pw/…`, date taken (ms),
   timezone offset, width, height, and video length (the `"76647426":[ms` field; 0 for photos).
5. The result is written to `www/photos.js` as `window.PHOTOS=[[url,taken,tz,w,h,videoMs],…]`.
   Only the links are stored. A failing album keeps its last good list (`tmp/last_<md5>.txt`).

Google image URLs take size suffixes. The page asks for `=w1280-h1280` (landscape) or `=w800-h1200` (portrait).
Video posters get `-no`, which removes the baked-in play icon. Video streams use `=m22` (720p), falling back to `=m18` (360p).

## The slideshow (`index.html`)

- Plain ES5 JavaScript and CSS animations, because the target is WebView 138 on a slow quad-core.
- A slide is one photo, or two portrait photos (`w/h < 1.15`) side by side. The partner is the upcoming portrait
  (within the next 300) taken closest in time.
- *Fill*: crop to the screen (or half) when that removes ≤ 22 % of the photo. Otherwise the whole photo is shown
  on a blurred copy of itself.
- Zoom effect: scale 1.0 → ~1.1, drift kept inside the zoomed area.
- `<meta name="referrer" content="no-referrer">` is required, because Google's video servers reject a localhost referrer.
- Each video play creates a fresh muted `<video>` element. Reusing one stalls on this WebView.
- **The page never navigates or reloads.** ImmichFrame sends any navigation to an external browser, which does not
  exist here, so the app crashes. The settings page therefore opens in an `<iframe>` overlay, and new settings are
  applied in place (`reloadCfg`). The slideshow also re-reads `config.json` every 60 s.
