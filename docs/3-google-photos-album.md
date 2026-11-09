# 3. Share a Google Photos album and add it to the frame

The frame reads a **shared album link**, the same kind of link you would send to a friend. It does not sign in to Google.

## Make the link

In the **Google Photos app** (phone):

1. **Library → New album** (or open an existing album) and add photos and videos.
2. Tap **Share** (or ⋮ → **Share album**) → **Create link** / **Copy link**.
   The link looks like `https://photos.app.goo.gl/AbCdEf123…`.
3. Make sure **link sharing is on**: open the album → ⋮ → **Options** → *Link sharing* = on.

On **photos.google.com** (computer): open the album → **Share** icon → **Create link** → copy.

Tips:
- **Let the album fill itself**: albums can automatically add photos of chosen people or pets ("live album":
  album → ⋮ → Options → *Automatically add photos*). New photos then reach the frame with no work at all.
- Several people can add to a shared album (turn on *Collaborate*).
- You can use **several albums**. The frame combines them and skips duplicates.

Privacy: **anyone who has the link can see the album.** Only share it with people you trust. The frame stores the link
on itself and on nothing else.

## Add it to the frame

On the frame: **tap the screen → Frame settings → Photo albums → + Add album**, paste or type the link, then tap **Save**.

Typing a long link on the frame's keyboard is tedious. Easier options:

- **From your phone or computer**: on the frame, Frame settings → *Remote settings* → turn on → Save. Open the address
  it shows (e.g. `http://192.168.1.50:8080/settings.html`) on your phone, paste the link, Save. You can turn remote
  settings off again afterwards.
- **At install time**: `./install.sh --album <link>` (first install only).

Under *Status* the settings page shows whether each album was read (✓ and the number of photos, or ✗ and why).
**Refresh now** re-reads the albums immediately. Otherwise they are re-read every 30 minutes (adjustable).

## What gets shown

- Photos and videos in the album, in shuffled order (or album order if *Shuffle* is off).
- The **date taken** comes from Google. Location and camera details are not shown.
- Photos are fetched from Google at screen size, a few ahead of time. Nothing is saved on the frame, so the frame needs
  internet to show photos. If an album can't be read for a while, the frame keeps using the last list it got.
