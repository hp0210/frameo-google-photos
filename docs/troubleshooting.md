# Troubleshooting

Logs on the frame (read them with `adb shell su 0 cat <file>`):

| File | What |
|---|---|
| `/data/albumframe/sync.log` | album reads: `album ok: N items`, or `album FAILED (reason)` |
| `/data/albumframe/ctl.log` | menu/settings actions, firewall and web server start |
| `/data/albumframe/gesture.log` | two-finger hold events |

Quick health check:
```bash
adb shell su 0 sh -c 'getprop init.svc.albumframe; ps -A -o ARGS | grep -E "httpd|gesture|albumframe/run" | grep -v grep; tail -3 /data/albumframe/sync.log'
```
Expected: `running`, a `busybox httpd -p 127.0.0.1:8080 …`, `sh /data/albumframe/gesture.sh`, `sh /data/albumframe/run.sh`, and `ok: total=…`.

| Problem | Fix |
|---|---|
| Frame does nothing on a USB‑C cable | Needs a USB‑A→C cable or its own adapter ([why](1-enable-adb.md#why-the-cable-matters)) |
| Frame turns off halfway through starting on USB | Lowest brightness first, a powered hub, or `./scripts/catch-usb.sh` |
| `adb devices` shows `unauthorized` | Tap *Allow* on the frame. If there is no prompt, switch ADB access off and on in Frameo |
| `adb devices` shows nothing over USB | The cable is charge-only. Test it with a phone |
| `su 0 id` fails | This frame has no preinstalled root, so this project won't work as-is |
| Black screen / "No photos yet" | Add an album (docs/3). Check `sync.log`. Make sure the album has *link sharing* on |
| `album FAILED (not a shared album link)` | Use the album's **share link**, not the browser address of your own album |
| Photos stopped updating, `sync.log` shows errors for every album | Google may have changed its page. `sync.sh` needs updating (see AGENTS.md) |
| No weather | Pick a location in Frame settings → On screen → Weather location |
| Stuck in Android settings | Hold two fingers on the screen for 2 s |
| Changes to home app / disabled apps lost after a restart | Android saves them lazily. Wait 20 s before `adb reboot` |
| Frameo came back after a restart | Same as above. Run `./install.sh` again |
| Video won't play | Takes up to ~12 s. Falls back to 360p, then skips. Check the Wi‑Fi signal |
| Can't reach `http://<ip>:8080/settings.html` from a phone | Turn on *Remote settings* on the frame first. The phone must be on the same Wi‑Fi |
| Frame lost Wi‑Fi | Tap → Wi‑Fi in the menu. If unreachable, use USB ADB: `adb shell am start -a android.settings.WIFI_SETTINGS` |
