# SpotiLoop - Spicetify Extension

High-precision A-B Looper for Spotify Desktop via Spicetify.

## Features
- **0ms Local Loop Engine**: Seeks are performed locally inside the Spotify desktop client with zero network latency.
- **Bottom Bar Icon**: Sits in the extra controls bar (next to lyrics/mic). Automatically shifts when other extensions are added or removed.
- **Timeline Markers & Dragging**: Green (Point A) and Red (Point B) pins right on Spotify's native playback scrubber. Click a pin to jump, or drag pins directly along the timeline!
- **Glowing Loop Region**: Visual highlight on the playback bar between Point A and Point B.
- **Floating Studio Flyout (Left-Click)**:
  - Editable digital time display boxes (accepts `1.47.`, `1.47`, `1:47`, seconds).
  - Micro-nudge grid (`-1.0s`, `+1.0s`, `-0.1s`, `+0.1s`).
  - Master Loop ON/OFF switch.
  - Loop counter badge.
  - "Set Current Position" buttons.
- **Context Menu (Right-Click)**: Fast 1-click actions: Set Point A, Set Point B, Jump, Toggle, Clear.
- **Middle-Click**: Quick toggle loop ON/OFF.
- **Per-Song Loop Memory**: Automatically remembers and restores loops for each song URI via `localStorage`.
- **Keyboard Hotkeys**:
  - `[` : Set Point A to current position
  - `]` : Set Point B to current position
  - `\` or `Alt + L` : Toggle Loop ON / OFF
  - `Shift + [` : Jump to Point A
  - `Shift + ]` : Jump to Point B

## Installation

1. Copy `spotiloop.js` to your Spicetify Extensions folder:
   ```powershell
   Copy-Item spotiloop.js "$env:APPDATA\spicetify\Extensions\spotiloop.js"
   ```

2. Register and apply:
   ```powershell
   spicetify config extensions spotiloop.js
   spicetify apply
   ```

3. Launch or restart Spotify.
