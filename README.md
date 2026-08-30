<div align="center">
  <img src="assets/logo.png" width="128" height="128" alt="Spoti Loop Icon" style="border-radius: 28px; box-shadow: 0 12px 36px rgba(29, 185, 84, 0.4);" />
  <br><br>

  # 🔁 Spoti Loop
  ### Precision A-B Audio Looper for Spotify
  
  **Master guitar riffs, complex drum fills, vocal harmonies, dance choreography, and language lessons with millisecond-accurate A-to-B repeat loops.**

  <br>

  [![Web Studio](https://img.shields.io/badge/🌐_Web_Studio-Live_App-1DB954?style=for-the-badge&logo=spotify&logoColor=white)](https://daivikopx.github.io/SpotiLoop/)
  [![Android Release](https://img.shields.io/badge/📱_Android_APK-v1.0.0_Download-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/DaivikOPX/SpotiLoop/releases/download/v1.0.0/Spoti-Loop.apk)
  [![Build Status](https://img.shields.io/github/actions/workflow/status/DaivikOPX/SpotiLoop/build-apk.yml?branch=main&style=for-the-badge&label=Build%20Status&logo=github)](https://github.com/DaivikOPX/SpotiLoop/actions)
  [![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

</div>

---

## ⚡ Quick Access

| Platform | Access Link | Description |
| :--- | :--- | :--- |
| **🌐 Web Studio** | **[daivikopx.github.io/SpotiLoop](https://daivikopx.github.io/SpotiLoop/)** | Instant zero-install web app. Works in any browser on PC, Mac, iPad, or Chromebook. |
| **📱 Android App** | **[Download Spoti-Loop.apk (v1.0.0)](https://github.com/DaivikOPX/SpotiLoop/releases/download/v1.0.0/Spoti-Loop.apk)** | Native Android build with background service and notification bar controls. |

---

## 🌟 Why Spoti Loop?

Standard media players don't allow precision section looping. When practicing difficult guitar solos, transcribing songs, learning choreography, or analyzing audio waveforms, you need to hear the exact same 2 to 10-second segment repeatedly without manual rewinding.

**Spoti Loop** hooks directly into your Spotify account via **Spotify Connect**, allowing you to set instantaneous **Point A** and **Point B** markers with millisecond granularity while controlling playback on any connected Spotify device.

```
       [ POINT A: 01:14.2 ]                      [ POINT B: 01:22.8 ]
───────────────●──────────────────────────────────────────●──────────────────►
               ▲                                          │
               └────────────── 🔁 Seamless Loop ──────────┘
```

---

## 🚀 Key Features

### 🎯 Sub-Second Granular Nudge Matrix
* **Precision Tuning**: Fine-tune your loop boundaries in **`±0.1s` (100ms)** and **`±1.0s` (1000ms)** steps using an ergonomic 2x2 matrix.
* **Transient Accuracy**: Catch the exact split-second pick attack of a guitar chord or downbeat of a drum kick.

### 🛡️ Autonomous Android Background Looper
* **Infinite Screen-Off Looping**: Features a dedicated Android **Foreground Service** (`FOREGROUND_SERVICE_MEDIA_PLAYBACK` + `DATA_SYNC`) running in an isolated background thread.
* **Doze-Mode Immunity**: Utilizes hardware `PARTIAL_WAKE_LOCK` and high-performance Wi-Fi locks to ensure loops run endlessly without stopping when your phone display is locked in your pocket.
* **Notification Drawer Controls**: View current loop markers, live loop repetition counters (`🔁 14x`), and tap **`⏹ Stop Loop`** directly from the notification tray.

### 🎛️ Interactive Waveform Timeline
* **Live Scrubbing**: Drag the glowing playhead across the progress bar for real-time timestamp updates and instantaneous seek on release.
* **Direct Pin Dragging**: Touch and drag the **Green Point A** or **Red Point B** pins directly along the timeline to visually resize your loop region.
* **Tap-to-Seek**: Tap anywhere along the timeline bar to jump playback instantly.

### 🧹 Smart Song Transition Auto-Reset
* When Spotify moves or skips to the next track, Spoti Loop automatically wipes all active markers and deactivates loop mode—ensuring old loop settings never accidentally loop the beginning of new songs.

### ⚡ Clean Task Lifecycle (`stopWithTask`)
* **Runs in Background**: Minimizing the app or using other apps (YouTube, Instagram, Tabs) keeps your loop running continuously.
* **Swipe to Stop**: Swiping Spoti Loop away from your phone's **Recents** menu immediately terminates background processes and removes the notification cleanly.

### 🔒 100% Private & Secure PKCE Authentication
* Connects directly to official Spotify Accounts using the industry-standard **OAuth 2.0 PKCE** flow.
* **Zero Backend Intermediaries**: Your tokens remain strictly encrypted on your local device. No credentials or listening telemetry are ever collected.

---

## 🕹️ User Guide: How to Use

```
 ┌──────────────┐      ┌─────────────────────────┐      ┌─────────────────────────┐
 │ 1. Play Song │ ───► │ 2. Connect Spoti Loop   │ ───► │ 3. Set Point A & B      │
 └──────────────┘      └─────────────────────────┘      └─────────────────────────┘
   (On Spotify App)      (Web Studio or Android)          (Tap 'Set Point A / B')
                                                                     │
                                                                     ▼
                                                        ┌─────────────────────────┐
                                                        │ 4. Tap '🔁 Enable Loop' │
                                                        └─────────────────────────┘
```

1. **Start Playback**: Open your regular Spotify app (on your Phone, Mac, PC, TV, or Speaker) and play any track.
2. **Launch Spoti Loop**: Open the [Web Studio](https://daivikopx.github.io/SpotiLoop/) or install the [Android APK](https://github.com/DaivikOPX/SpotiLoop/releases/download/v1.0.0/Spoti-Loop.apk).
3. **Authorize**: Tap **Authorize with Spotify** to link playback control.
4. **Set Boundaries**:
   * Tap **Set Point A** when your desired section starts.
   * Tap **Set Point B** when your section ends.
5. **Start Looping**: Tap the large **`🔁 Enable Loop`** button.
6. **Fine-Tune**:
   * Use **`[ -0.1s ]` / `[ +0.1s ]`** to micro-adjust transients.
   * Use **`[ Jump to A ]`** or **`[ Jump to B ]`** to audition your start/end points.

---

## 🛠️ Technology Stack

* **Framework**: [Flutter](https://flutter.dev/) (Multi-platform Dart SDK)
* **Background Architecture**: Native Android `ForegroundService` with Isolate communication via `flutter_foreground_task`
* **API Integration**: Official Spotify Web API (`v1/me/player`, `v1/me/player/seek`)
* **Authentication**: OAuth 2.0 PKCE (RFC 7636) with SHA-256 Code Challenge
* **CI/CD Pipeline**: GitHub Actions automated builds & GitHub Pages deployment

---

## 💻 Local Development & Build

### Prerequisites
* Flutter SDK (3.10.0 or later)
* Android SDK (API 21+) & Java 17

### 1. Clone the Repository
```bash
git clone https://github.com/DaivikOPX/SpotiLoop.git
cd SpotiLoop
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Locally

#### Web:
```bash
flutter run -d chrome
```

#### Android Device / Emulator:
```bash
flutter run -d android
```

### 4. Build Production Artifacts

#### Build Android APK:
```bash
flutter build apk --release
```
*Output artifact will be available at:* `build/app/outputs/flutter-apk/app-release.apk`

#### Build Web App:
```bash
flutter build web --release --base-href "/SpotiLoop/"
```

---

## 🛡️ Android Permissions Explained

| Permission | Purpose |
| :--- | :--- |
| `INTERNET` | Communicates with Spotify Web API to sync playback and issue seek commands. |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Grants Android OS priority for uninterrupted background loop execution. |
| `WAKE_LOCK` | Prevents CPU sleep from pausing timing calculations while phone display is off. |
| `POST_NOTIFICATIONS` | Displays the active loop status and interactive **Stop** button in notification tray. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Exempts the app from OEM battery kill policies (Samsung OneUI, Xiaomi HyperOS, etc.). |

---

## 📄 License

This project is open-source under the terms of the **[MIT License](LICENSE)**.

---

<div align="center">
  <sub>Built with ❤️ for musicians, dancers, transcribers, and music lovers worldwide.</sub>
</div>
