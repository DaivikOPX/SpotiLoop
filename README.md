# 🔁 SpotiLoop Pro — Spotify A-B Looper Studio

<div align="center">
  <img src="assets/logo.png" width="140" alt="SpotiLoop Logo" style="border-radius: 28px;" />
  <h3>Seamless A-to-B section looping inside the official Spotify player with sub-second precision.</h3>
</div>

---

## ✨ Features

- **🎧 Native Spotify Playback**: Audio plays directly inside your official Spotify app (Desktop, Mobile, Web, Smart Speakers) via Spotify Connect.
- **⚡ Flexible Time Inputs**: Type timestamps using dot notation (`1.14`, `1.14.5`), colons (`1:14`), or pure seconds (`74.5`).
- **🛡️ Background Playback Immune to Tab Sleeping**: Dual-engine background loop architecture (unthrottled Native OS ticker + Web Audio keep-alive).
- **💾 0-Click Auto-Login**: Secure local session persistence (`.spotify_session.json`) with auto-token refresh.
- **🎯 Smart App Sync**: Changing tracks or pausing in the Spotify app pauses the loop without wiping Point A / Point B timestamps.
- **📱 Multi-Platform**: Run locally on Windows/Mac/Linux via Node.js web studio or install the native Android Flutter app.

---

## 🚀 Quick Start (Web / Desktop)

### 1. Prerequisites
- **Node.js** (v16 or higher)
- **Spotify Premium** account

### 2. Spotify App Setup (1 Minute)
1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Click **Create App** and set:
   - **App Name**: `SpotiLoop`
   - **Redirect URIs**:
     - `http://127.0.0.1:8888/callback` (for Web/Desktop)
     - `spotiloop://callback` (for Android App)
   - **Which API/SDK are you planning to use?**: Select **Web API**.
3. Save and copy your **Client ID**.

### 3. Run SpotiLoop
```bash
# Clone the repository
git clone https://github.com/your-username/SpotiLoop.git
cd SpotiLoop

# Copy environment template (Optional)
cp .env.example .env
# Add your SPOTIFY_CLIENT_ID to .env, or paste it directly in the web UI!

# Start the server
node server.js
```
Open **[http://127.0.0.1:8888/](http://127.0.0.1:8888/)** in your browser and connect with Spotify!

---

## 📱 How to Use on Android

### Method 1: Instant Wi-Fi Web Controller (No install required)
1. Ensure your phone and PC are connected to the same Wi-Fi network.
2. Find your PC's local IP address (e.g. `192.168.1.15`).
3. Open `http://<YOUR_PC_IP>:8888/` in Chrome/Safari on your phone.
4. Tap **Add to Home Screen** to install it as a lightweight PWA!

### Method 2: Automatic GitHub APK Build
1. Push this repository to your GitHub account.
2. The included GitHub Actions workflow (`.github/workflows/build_apk.yml`) will **automatically build the release APK for free**.
3. Go to the **Actions** tab on your GitHub repository, click the latest workflow run, and download `spotiloop-release-apk`.
4. Install the `.apk` on your Android phone!

### Method 3: Local Flutter Build
If you have Flutter installed:
```bash
flutter pub get
flutter build apk --release
```
The APK will be generated in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔒 Security & Privacy

- **Zero Server Tracking**: SpotiLoop runs 100% locally on your machine.
- **PKCE OAuth 2.0 Flow**: No client secret is ever stored or required.
- **Strict Git Ignore**: Secrets (`.env`, `.spotify_session.json`) are strictly excluded from git tracking.

---

## 📜 License
MIT License. Free and open source for everyone!
