# Karaoke (Apple Vision Pro)

A visionOS karaoke app: pick a 1, 3 or 5 minute set, press **Start**, and sing
on an immersive night-time stage while the lyrics play on a board above it.
Every song is public domain and played as simple tones; nothing is recorded.

## Run it on a Vision Pro

You need a Mac with **Xcode 26.2 or newer**, and a Vision Pro on **visionOS 26.2 or newer**.

1. Download the project:
   `git clone https://github.com/ResearchProjectsFlexLab/karaoke-app.git`
   (or on GitHub: **Code › Download ZIP**, then unzip).
2. Open `Karaoke.xcodeproj` in Xcode.
3. Pair the Vision Pro (first time only):
   - On the Vision Pro: **Settings › General › Remote Devices**, and keep that screen open.
   - On the Mac: **Xcode › Window › Devices and Simulators**, choose the Vision Pro, and enter the code it shows.
   - The Mac and the Vision Pro need to be on the same Wi-Fi network.
4. Turn on Developer Mode on the Vision Pro: **Settings › Privacy & Security › Developer Mode**, then restart it.
5. Signing: click the **Karaoke** project › **Karaoke** target › **Signing & Capabilities**.
   - If your Apple ID is on the FlexLab team, leave the team as it is.
   - Otherwise pick your own **Team**. If Xcode says the bundle identifier is
     unavailable, change `FlexLab.Karaoke` to something unique, for example
     `yourname.Karaoke`.
6. At the top of Xcode, pick the Vision Pro as the run destination and press **Run** (⌘R).
   The first time, the Vision Pro may ask you to trust the developer:
   **Settings › General › VPN & Device Management**.

## Session logs

When a set finishes, or you press **Stop**, the app saves that run's log automatically
and shows **Log saved** with the file name. To find the logs on the Vision Pro, open
**Files › On My Apple Vision Pro › Karaoke**. They look like this:

```
karaoke-log_2026-11-07_16-56-35.txt
```

Each line has a timestamp to the millisecond: `session_start`, `song_start <title>`,
`lyric_line <n> <text>`, and `song_finished` or `session_stop`.

To copy logs to the Mac, share them from the Files app with AirDrop, or open
**Xcode › Window › Devices and Simulators**, pick the Vision Pro, select **Karaoke**,
and download its container.
