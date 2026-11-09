# 1. Turn on ADB and connect

ADB (Android Debug Bridge) lets your computer control the frame. Once it works over Wi‑Fi you can unplug the cable.

## What you need

- **Android platform-tools** (`adb`):
  - macOS: `brew install android-platform-tools`
  - Debian/Ubuntu: `sudo apt install adb`
  - others: <https://developer.android.com/tools/releases/platform-tools>
- A **USB‑A (big end) to USB‑C cable that carries data.** Many cheap cables only charge. To test a cable, plug an
  Android phone into the computer with it: if the computer sees the phone, the cable carries data.
- If your computer only has USB‑C ports: a **USB‑C to USB‑A hub/adapter**.

## Why the cable matters

The frame has a single USB‑C port, and it is built without the small resistors USB‑C uses to ask for power.
Because of that:

- a **USB‑C to USB‑C** cable gives it **no power at all**: nothing happens;
- a **USB‑A to USB‑C** cable works, because USB‑A always supplies power;
- the frame's **own power adapter** works, but it has no data lines, so no ADB.

A computer's USB‑A port (or a hub's) only gives about 0.5 A. That is often **not enough to boot the frame at
normal brightness**: it starts, then the screen goes black halfway through starting up. Fixes, easiest first:

1. **Turn the screen brightness to the lowest setting** in Frameo *before* you plug it into the computer
   (swipe down from the top in Frameo, or Settings → Display). It then uses much less power while starting.
2. Use a **powered USB hub** (one with its own power supply), or a short, thick cable.
3. Use the **catch** trick below: ADB only needs a few seconds of connection to switch over to Wi‑Fi.

## Steps

1. **Set up the frame normally first**: run Frameo's setup wizard and **connect it to your Wi‑Fi**. Frameo saves Wi‑Fi in
   Android itself, so it keeps working after Frameo is turned off.
2. **Turn on ADB in Frameo**: **Settings → About → turn on "Beta program", then turn on "ADB access"**
   (on some versions the switch is called "Enable ADB"). If it shows up as *unauthorized* later, switch it off and on again.
3. **Note the frame's IP address**: Frameo Settings → About / Network (e.g. `192.168.1.50`).
4. **Try Wi‑Fi ADB first**. Many frames already allow it:
   ```bash
   adb connect 192.168.1.50:5555
   adb devices
   ```
   If it shows `192.168.1.50:5555  device`, **you are done**: go to [step 2](2-install.md).
5. Otherwise, **connect by USB**. Turn the brightness to the lowest setting, then connect the frame to the computer with the USB‑A→C cable.
   If the frame shows **"Allow USB debugging?"**, tick *Always allow from this computer* and tap **Allow**.
   ```bash
   adb devices          # should list the frame as "device"
   adb tcpip 5555       # switch ADB to Wi-Fi
   adb shell su 0 setprop persist.adb.tcp.port 5555   # keep it on Wi-Fi after restarts
   adb connect 192.168.1.50:5555
   ```
6. **If the frame keeps turning off on USB power**, use the catch script. It waits for the frame and switches it to
   Wi‑Fi ADB the moment it appears, while the frame is still starting up:
   ```bash
   ./scripts/catch-usb.sh
   ```
   Plug the frame in (or turn it on) while the script is waiting. Tap **Allow** on the frame if asked. When it says *Done*,
   power the frame from its own adapter again and `adb connect <ip>:5555`.

## Check it worked

```bash
adb connect 192.168.1.50:5555
adb shell su 0 id
```
should print `uid=0(root) …`. That means you have root, which the installer needs.
Next: **[2. Back up and install](2-install.md)**.
