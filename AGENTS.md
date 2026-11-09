# Notes for AI assistants (Claude, ChatGPT, Codex, Cursor, …)

You are helping someone install or change **AlbumFrame** on a Frameo photo frame over ADB. Read this whole file before
running anything. The README and `docs/` are written for the human. This file covers what you need to avoid breaking the frame.

## Ground rules

- **Never write to a block device or partition** (`dd of=/dev/block/...`, `fastboot flash`, `mkfs`, etc.). This project
  never needs to. `scripts/backup.sh` only *reads* partitions.
- **Never delete the user's backups** (`backup-*/` folders, or anything they made themselves). Don't run `rm -rf` on paths built from variables.
- **Back up before the first install**: `./scripts/backup.sh`. Ask the user before skipping it.
- Prefer the scripts (`install.sh`, `install.sh --update`, `uninstall.sh`) over doing the steps by hand. They are tested.
- Ask the user before: restarting the frame, disabling or enabling apps, changing `/system`, or anything they can't undo.
- The album link and the frame's IP are personal. Don't paste them into public places (issues, commits).

## The device (tested: REUMAR NZ-DP1002)

- Rockchip RK3326, Android 8.1 (SDK 27), `armeabi-v7a`, 1280×800 touchscreen (`gslX680`), 1 GB RAM, no speaker.
- Root: preinstalled su. Run commands as `adb shell su 0 <cmd>` (no prompt). `/system` can be remounted read-write.
- **No status bar or navigation bar** (the vendor disabled `com.android.systemui`). Do not try to re-enable it,
  and don't set `qemu.hw.mainkeys`: it doesn't help. The user's way out of other apps is the two-finger 2‑second hold.
- Power: needs a **USB‑A→C** cable (no CC resistors). It can brown out on computer USB power at normal brightness.
- `/system/bin/busybox` is v1.22: it has `httpd`, `awk`, `sed`, `timeout`, `setsid`, `pkill`, but **no `date`, `stat`, `pgrep`**.
  Use the system `date`, `stat`, `pgrep` (toybox) instead.

## Quirks that cost hours, so don't rediscover them

1. **Android saves app state lazily.** After `pm disable-user`, `pm enable` or `cmd package set-home-activity`,
   **wait ~20 s before `adb reboot`**, or the change is lost.
2. **ImmichFrame crashes on any page navigation or `location.reload()`**: it hands URLs to an external browser that
   doesn't exist. `index.html` must never navigate. Settings open in an iframe overlay, and config is applied in place.
3. ImmichFrame's own swipe-down settings panel is disabled with the pref `settingsLock=true`. Keep it that way.
4. `getevent` output is **block-buffered when piped**, so `gesture.sh` reads `/dev/input/eventN` raw with `dd | od`.
5. The static curl resolves DNS from **`/system/etc/resolv.conf`** (c-ares). Without that file, every sync fails with DNS errors.
6. `adb exec-out "su 0 …"` **corrupts binary output** (it goes through a pty). Copy files to `/sdcard` first, then `adb pull`.
7. Quoting through `adb shell su 0 sh -c '…'` is fragile (mksh, then su, then sh). For anything non-trivial, write a script
   on the host, `adb push` it to `/data/local/tmp/` under a **unique name**, and run `su 0 sh /data/local/tmp/<name>.sh`.
   Never name a helper `run.sh`: one once overwrote the real `/data/albumframe/run.sh`.
8. Google video URLs need **no referrer** (`<meta name="referrer" content="no-referrer">`), and a fresh muted `<video>` per play.
9. The stock WebView 61 is too old. The installer replaces it with LineageOS WebView 138 (sha256 `b7268786…cf11`),
   the last version that supports Android 8.

## Layout

```
install.sh / uninstall.sh       host scripts (bash, macOS/Linux)
scripts/lib.sh                  shared helpers (device pick, root check, wait for boot)
scripts/backup.sh               read-only partition backup → ./backup-*/
scripts/catch-usb.sh            catch the frame on USB during boot, switch to Wi‑Fi ADB
scripts/device-install.sh       runs ON the frame as root (full | update)
scripts/device-uninstall.sh     runs ON the frame as root
frame/                          files that end up in /data/albumframe (+ albumframe.rc in /system/etc/init)
docs/                           human docs; docs/how-it-works.md has the internals
```

## Standard checks

```bash
adb devices                                            # frame listed as "device"
adb shell su 0 id                                      # uid=0
adb shell getprop init.svc.albumframe                  # running
adb shell su 0 tail -5 /data/albumframe/sync.log       # "ok: total=N"
adb shell dumpsys activity activities | grep mResumedActivity   # com.immichframe.immichframe/.MainActivity
adb exec-out screencap -p > screen.png                 # look at the screen (PNG is fine through exec-out without su)
```

## Making changes

- Edit files in `frame/`, then `./install.sh --update`. It copies them and restarts the service, with no reboot and settings kept.
- After changing `index.html`, the WebView must reload. `--update` does this by restarting ImmichFrame through the service restart.
  If it doesn't, run `adb shell su 0 am force-stop com.immichframe.immichframe && adb shell input keyevent KEYCODE_HOME`.
- Keep `index.html` ES5-friendly and light. Test on the real frame with screenshots: things that work in desktop Chrome may not work here.
- Settings: add the default to `frame/defaults.js`, the control to `frame/settings.html` (populate + save), and use it in
  `applyCfg()` in `index.html`.
- If album sync breaks, save a fresh copy of the share page (`curl -L <link>`) and compare it with the patterns in
  `sync.sh` (`ITEMPAT`, `VIDAWK`, the `snAcKc` RPC).
