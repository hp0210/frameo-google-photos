# 2. Back up and install

All commands run **on your computer**, from the folder of this repository, while `adb devices` lists the frame.
Add `--device <frame-ip>` to any script to connect over Wi‑Fi.

## Back up first

```bash
./scripts/backup.sh --device 192.168.1.50
```

This copies every partition of the frame except `userdata` (about 3.5 GB) into `./backup-<frame>-<date>/`.
It also saves Frameo's app data and the original WebView, and checks every image against a SHA‑256 checksum taken on the frame.
It only **reads** the frame's partitions, never writes to them. The images are kept in a temporary folder on the frame
and each one is deleted only after its copy on your computer is verified. Takes 10–20 minutes over Wi‑Fi.

Keep that folder somewhere safe. It is your way back if anything goes badly wrong. It is excluded from git.

## Install

```bash
./install.sh --device 192.168.1.50
# or set the album at the same time:
./install.sh --device 192.168.1.50 --album https://photos.app.goo.gl/XXXXXXXX
```

The script checks the frame (root, Android 8.1, `armeabi-v7a`) and downloads what it needs into `./downloads/`,
checking each file against a known SHA‑256. Then it lists what it will do and asks before changing anything:

| Step | What | Why |
|---|---|---|
| WebView 61 → 138 | Replaces `/system/app/webview/webview.apk` with the LineageOS build; the original is kept in `/data/albumframe-original/` | The stock WebView is too old for the slideshow page and Google's video player. 138 is the newest that supports Android 8. |
| ImmichFrame | Installs the open-source ImmichFrame app and sets it to show `http://127.0.0.1:8080/index.html` full screen | A simple full-screen browser that can be the home screen |
| AlbumFrame | Copies `frame/*` into `/data/albumframe`, plus a static `curl` | The slideshow, settings page and album sync |
| Boot service | `/system/etc/init/albumframe.rc` (+ `/system/etc/resolv.conf` if missing) | Starts the slideshow web server and sync at every boot, as root |
| Home screen | ImmichFrame becomes the home app; **Frameo**, **Adups FOTA** and **Rockchip update** are disabled | Frameo would take over the screen. The updaters phone home and could overwrite these changes. |
| Firewall | Gboard (the keyboard) cannot reach the internet; local network still works | The keyboard app sends usage data to Google |
| ADB | Wi‑Fi ADB stays on, on port 5555 | So you can update or undo later |

Then it waits 20 seconds (Android saves app changes lazily; restarting sooner can lose them), restarts the frame,
and waits for it to come back. After about a minute you should see "No photos yet" or your photos.

Your Frameo photos and pairing are **not deleted**, only hidden while Frameo is turned off.

## Updating

After `git pull`:
```bash
./install.sh --update --device 192.168.1.50
```
This copies the new slideshow files and restarts the slideshow. No restart of the frame, and your settings are kept.

## Undo

```bash
./uninstall.sh --device 192.168.1.50                    # back to Frameo, keeps WebView 138 (works fine with Frameo)
./uninstall.sh --device 192.168.1.50 --restore-webview  # also put the original WebView back
```

For a complete restore you can flash the partition images from the backup with Rockchip tools. That is rarely needed
and not covered here.

Next: **[3. Share a Google Photos album](3-google-photos-album.md)**.
