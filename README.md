# Karaoke (Apple Vision Pro)

A visionOS karaoke app for a study session on an immersive night-time stage.
Every song is public domain and played as simple tones; no audio is recorded.

## How a session runs

1. **Instructions:** pick a 1, 3 or 5 minute set and read the steps, then press **Start baseline**.
2. **Baseline (1 min):** sit still and breathe normally. The stage stays dim and calm.
3. **Start karaoke:** when the baseline ends, a separate button starts the songs.
4. **Karaoke:** sing along with the lyrics on the board.
5. **Recovery (1 min):** starts automatically after the last song. Sit back and relax.

**End session** stops at any point; whatever was recorded is still saved.

## Run it on a Vision Pro

You need a Mac with **Xcode 26 or newer**, and a Vision Pro (original or M5) on **visionOS 26 or newer**.

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

Each line has a timestamp to the millisecond, in this order: `session_start`, `set_length`,
`baseline_start`, `baseline_end`, `karaoke_start`, `song_start <title>`, `lyric_line <n> <text>`,
`song_finished`, `recovery_start`, `recovery_end`, `session_end`. If the session is ended early,
the log has `session_stop during <phase>` instead.

To copy logs to the Mac, share them from the Files app with AirDrop, or open
**Xcode › Window › Devices and Simulators**, pick the Vision Pro, select **Karaoke**,
and download its container.
