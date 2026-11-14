# AlbumFrame: Google Photos on a Frameo frame

Turn a cheap Frameo digital photo frame into a frame that shows a **Google Photos shared album**,
with no Frameo app, no cloud account on the frame, and no manual uploads. Add photos to the album on your phone
and they show up on the frame by themselves.

Tested on the **REUMAR NZ-DP1002** (10.1", 1280×800, Rockchip RK3326, Android 8.1, Frameo 1.32).
Other Frameo frames with the same insides (Android 8.1, `armeabi-v7a`, preinstalled `su`) will probably work.

## What you get

- Slideshow of one or more Google Photos **shared album links**. Photos load on demand, nothing is stored on the frame.
- Landscape photos fill the screen. **Portrait photos are shown two side by side**, picked from around the same day.
- Slow zoom-in effect, cross-fade, shuffle, the date each photo was taken ("3 years ago today"), and optionally the camera and lens.
- Clock and local weather (Open‑Meteo, no account or API key).
- **Videos** show with a ▶ button and play (muted) when tapped.
- **Tap the screen** for a menu: brightness, previous/next, Wi‑Fi, Frame settings, Restart, Turn off.
- **Frame settings** page on the frame (and optionally from your phone on the same Wi‑Fi): albums, timing,
  effects, clock/weather, night mode.
- **Hold two fingers on the screen for 2 seconds** anywhere (e.g. inside Android settings) to get back to the slideshow.
- Frameo app and the vendor's auto-updaters are switched off, so the frame no longer "phones home".
  The keyboard app (Gboard) is blocked from the internet.

## How to install (overview)

You need a computer (macOS or Linux, Windows via WSL), a **USB‑A to USB‑C data cable**, and about 30 minutes.

1. **[Turn on ADB and connect](docs/1-enable-adb.md)** – the fiddly part. The frame only powers up from USB‑A, and needs low brightness to stay on.
2. **[Back up and install](docs/2-install.md)** – `./scripts/backup.sh`, then `./install.sh`.
3. **[Share a Google Photos album and add the link](docs/3-google-photos-album.md)**.
4. **[Using the frame](docs/using-the-frame.md)**: the menu, gestures, settings and night mode.

Something wrong? See **[troubleshooting](docs/troubleshooting.md)**. Want Frameo back? `./uninstall.sh`.

**Using an AI assistant (Claude, ChatGPT, …) to help?** Point it at **[AGENTS.md](AGENTS.md)** first. It explains
this device's quirks and the checks to run, so the assistant does not have to rediscover them.

## How it works

Read **[docs/how-it-works.md](docs/how-it-works.md)** for the details. In short:

```
boot ─▶ /system/etc/init/albumframe.rc ─▶ /data/albumframe/run.sh (root)
          ├─ firewall.sh     block Gboard's internet access
          ├─ web.sh          busybox httpd on 127.0.0.1:8080 → slideshow + settings pages
          ├─ gesture.sh      two-finger hold → Home
          └─ sync.sh         every 30 min: read the shared album(s) → www/photos.js (links only)
ImmichFrame app (home screen, full-screen WebView 138) ─▶ http://127.0.0.1:8080/index.html
```

## Disclaimer

This roots-level tinkering is at your own risk. It can void your warranty, and a mistake can leave the frame unusable.
Make the backup. This project is not affiliated with Frameo, Google, REUMAR or ImmichFrame.
It reads **public shared-album pages** the way a browser does. Google can change those pages at any time and stop it working.

## Credits

- [ImmichFrame Android](https://github.com/immichFrame/ImmichFrame_Android): the full-screen web view app (downloaded at install).
- [LineageOS WebView prebuilts](https://github.com/LineageOS/android_external_chromium-webview_prebuilt_arm): WebView 138 for Android 8.
- [static-curl](https://github.com/stunnel/static-curl): curl for the frame.
- [Open‑Meteo](https://open-meteo.com): weather and location search.

License: MIT (see [LICENSE](LICENSE)). The downloaded third-party apps keep their own licenses.
