// ============================================================================
// SpotiLoop - High-Precision Spotify A-B Looper for Spicetify
// ============================================================================

(function SpotiLoopInit() {
    // Wait until Spicetify Core APIs are ready
    if (!window.Spicetify || !Spicetify.Player || !Spicetify.Playbar || !Spicetify.showNotification) {
        setTimeout(SpotiLoopInit, 200);
        return;
    }

    // ========================================================================
    // 1. STATE & STORAGE
    // ========================================================================
    const state = {
        pointA: null,       // Milliseconds
        pointB: null,       // Milliseconds
        enabled: false,
        loopCount: 0,
        flyoutOpen: false,
        contextMenuOpen: false,
        dragging: null,     // 'A' or 'B'
        lastSeekTime: 0,
        activeTrackUri: null,
    };

    let checkInterval = null;
    let timelineObserver = null;
    let playbarButton = null;

    // SVG Icons
    const ICON_LOOP = `<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
        <path d="M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z"/>
    </svg>`;

    // Format milliseconds to mm:ss.s
    function formatTime(ms) {
        if (ms == null || isNaN(ms)) return '--:--.-';
        const totalSecs = Math.max(0, ms / 1000);
        const mins = Math.floor(totalSecs / 60);
        const secs = totalSecs % 60;
        const minsStr = String(mins).padStart(2, '0');
        const secsStr = secs.toFixed(1).padStart(4, '0');
        return `${minsStr}:${secsStr}`;
    }

    // Parse user input strings into milliseconds
    function parseTimeToMs(str) {
        if (!str) return null;
        let s = str.trim().replace(/\s+/g, ' ');
        s = s.replace(/[\.:,\s]+$/, ''); // Strip trailing dots/colons e.g. "1.47." -> "1.47"
        if (!s) return null;

        // Colon format (mm:ss or mm:ss.s)
        if (s.includes(':')) {
            const parts = s.split(':');
            if (parts.length === 2) {
                const m = parseFloat(parts[0]);
                const sec = parseFloat(parts[1]);
                if (!isNaN(m) && !isNaN(sec)) return Math.round((m * 60 + sec) * 1000);
            } else if (parts.length === 3) {
                const h = parseFloat(parts[0]);
                const m = parseFloat(parts[1]);
                const sec = parseFloat(parts[2]);
                if (!isNaN(h) && !isNaN(m) && !isNaN(sec)) return Math.round((h * 3600 + m * 60 + sec) * 1000);
            }
        }

        // Space format ("1 47")
        if (s.includes(' ')) {
            const parts = s.split(' ');
            if (parts.length === 2) {
                const m = parseFloat(parts[0]);
                const sec = parseFloat(parts[1]);
                if (!isNaN(m) && !isNaN(sec)) return Math.round((m * 60 + sec) * 1000);
            }
        }

        // Dot format ("1.47", "1.47.5")
        if (s.includes('.')) {
            const dp = s.split('.');
            if (dp.length === 3) {
                const m = parseFloat(dp[0]);
                const sec = parseFloat(dp[1]);
                const tenths = parseFloat('0.' + dp[2]);
                if (!isNaN(m) && !isNaN(sec) && !isNaN(tenths)) return Math.round((m * 60 + sec + tenths) * 1000);
            } else if (dp.length === 2) {
                const p0 = parseFloat(dp[0]);
                const p1 = parseFloat(dp[1]);
                if (dp[1].length === 2 && !isNaN(p0) && !isNaN(p1) && p1 < 60 && p0 < 60) {
                    return Math.round((p0 * 60 + p1) * 1000);
                }
                if (p0 >= 60) {
                    const totalSec = parseFloat(s);
                    if (!isNaN(totalSec)) return Math.round(totalSec * 1000);
                }
            }
        }

        // Plain numbers or raw seconds
        const num = parseFloat(s);
        if (!isNaN(num) && num >= 0) {
            if (/^\d{3,4}$/.test(s)) {
                const pad = s.padStart(4, '0');
                const m = parseInt(pad.substring(0, 2), 10);
                const sec = parseInt(pad.substring(2), 10);
                if (sec < 60) return (m * 60 + sec) * 1000;
            }
            return Math.round(num * 1000);
        }
        return null;
    }

    // Storage per track URI
    function getTrackUri() {
        return Spicetify.Player.data?.item?.uri || null;
    }

    function saveCurrentTrackLoop() {
        const uri = getTrackUri();
        if (!uri) return;
        try {
            if (state.pointA == null && state.pointB == null) {
                localStorage.removeItem(`spotiloop_${uri}`);
            } else {
                localStorage.setItem(`spotiloop_${uri}`, JSON.stringify({
                    pointA: state.pointA,
                    pointB: state.pointB,
                    enabled: state.enabled,
                }));
            }
        } catch (e) {}
    }

    function loadTrackLoop(uri) {
        if (!uri) return;
        try {
            const raw = localStorage.getItem(`spotiloop_${uri}`);
            if (raw) {
                const data = JSON.parse(raw);
                state.pointA = data.pointA ?? null;
                state.pointB = data.pointB ?? null;
                state.enabled = data.enabled ?? false;
                state.loopCount = 0;
            } else {
                state.pointA = null;
                state.pointB = null;
                state.enabled = false;
                state.loopCount = 0;
            }
        } catch (e) {
            state.pointA = null;
            state.pointB = null;
            state.enabled = false;
            state.loopCount = 0;
        }
        updateAll();
    }

    // ========================================================================
    // 2. HIGH-PRECISION 0ms LOOP ENGINE
    // ========================================================================
    function startEngine() {
        if (checkInterval) clearInterval(checkInterval);
        checkInterval = setInterval(tick, 30);
    }

    function tick() {
        if (!state.enabled || state.pointA == null || state.pointB == null) return;
        if (state.pointA >= state.pointB) return;
        if (!Spicetify.Player.isPlaying()) return;

        const currentMs = Spicetify.Player.getProgress();
        const now = Date.now();

        // Check if track reached or passed Point B
        if (currentMs >= state.pointB && now - state.lastSeekTime > 300) {
            state.lastSeekTime = now;
            Spicetify.Player.seek(state.pointA);
            state.loopCount++;
            updateLoopCountDisplay();
        }
    }

    // ========================================================================
    // 3. UI INJECTION & STYLES
    // ========================================================================
    function injectStyles() {
        if (document.getElementById('spotiloop-styles')) return;
        const style = document.createElement('style');
        style.id = 'spotiloop-styles';
        style.innerHTML = `
            /* Custom Playbar Button */
            .spotiloop-playbar-btn {
                background: transparent;
                border: none;
                color: #B3B3B3;
                width: 32px;
                height: 32px;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                transition: color 0.15s ease, transform 0.15s ease, filter 0.15s ease;
                border-radius: 50%;
                margin: 0 4px;
                padding: 0;
            }

            .spotiloop-playbar-btn:hover {
                color: #FFFFFF;
                transform: scale(1.1);
            }

            .spotiloop-playbar-btn.spotiloop-btn-active {
                color: #1DB954 !important;
                filter: drop-shadow(0 0 8px rgba(29, 185, 84, 0.85)) !important;
            }

            /* Timeline Scrubber Markers */
            .spotiloop-timeline-container {
                position: absolute;
                inset: 0;
                pointer-events: none;
                z-index: 20;
            }

            .spotiloop-highlight-zone {
                position: absolute;
                top: 0;
                bottom: 0;
                background: rgba(29, 185, 84, 0.35);
                border-left: 2px solid #1DB954;
                border-right: 2px solid #F43F5E;
                border-radius: 4px;
                box-shadow: 0 0 8px rgba(29, 185, 84, 0.4);
                transition: background 0.15s ease;
                pointer-events: none;
            }

            .spotiloop-pin {
                position: absolute;
                top: 50%;
                width: 14px;
                height: 14px;
                border-radius: 50%;
                transform: translate(-50%, -50%);
                cursor: grab;
                pointer-events: auto;
                box-shadow: 0 2px 8px rgba(0,0,0,0.85);
                transition: transform 0.1s ease, filter 0.1s ease;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 8.5px;
                font-weight: 900;
                color: #ffffff;
                font-family: monospace;
                user-select: none;
                z-index: 25;
            }

            .spotiloop-pin:hover {
                transform: translate(-50%, -50%) scale(1.35);
                filter: brightness(1.25);
            }

            .spotiloop-pin:active {
                cursor: grabbing;
                transform: translate(-50%, -50%) scale(1.45);
            }

            .spotiloop-pin-a {
                background: #1DB954;
                border: 2px solid #ffffff;
            }

            .spotiloop-pin-b {
                background: #F43F5E;
                border: 2px solid #ffffff;
            }

            /* Floating Studio Flyout */
            #spotiloop-flyout {
                position: fixed;
                bottom: 95px;
                right: 60px;
                width: 320px;
                background: #12131A;
                border: 1px solid #232534;
                border-radius: 14px;
                box-shadow: 0 16px 40px rgba(0, 0, 0, 0.85);
                backdrop-filter: blur(20px);
                color: #ffffff;
                padding: 16px;
                font-family: var(--encore-body-font-stack, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif);
                z-index: 999999;
                display: none;
                animation: spotiloop-pop 0.2s cubic-bezier(0.16, 1, 0.3, 1);
            }

            @keyframes spotiloop-pop {
                from { opacity: 0; transform: translateY(12px) scale(0.96); }
                to { opacity: 1; transform: translateY(0) scale(1); }
            }

            .spotiloop-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 12px;
                padding-bottom: 10px;
                border-bottom: 1px solid #1E202C;
            }

            .spotiloop-title {
                display: flex;
                align-items: center;
                gap: 8px;
                font-size: 14px;
                font-weight: 800;
                letter-spacing: -0.2px;
                color: #ffffff;
            }

            .spotiloop-badge {
                font-size: 11px;
                font-weight: 700;
                background: rgba(29, 185, 84, 0.15);
                color: #1DB954;
                padding: 2px 7px;
                border-radius: 10px;
                border: 1px solid rgba(29, 185, 84, 0.3);
            }

            .spotiloop-master-toggle {
                display: flex;
                align-items: center;
                justify-content: space-between;
                background: #181924;
                border: 1px solid #26293A;
                border-radius: 10px;
                padding: 8px 12px;
                margin-bottom: 14px;
                cursor: pointer;
                transition: all 0.2s ease;
            }

            .spotiloop-master-toggle:hover {
                border-color: #383C54;
                background: #1C1E2B;
            }

            .spotiloop-toggle-switch {
                position: relative;
                width: 36px;
                height: 20px;
                background: #2E3244;
                border-radius: 12px;
                transition: background 0.2s;
            }

            .spotiloop-toggle-switch::after {
                content: '';
                position: absolute;
                top: 2px;
                left: 2px;
                width: 16px;
                height: 16px;
                background: #ffffff;
                border-radius: 50%;
                transition: transform 0.2s;
            }

            .spotiloop-master-toggle.active .spotiloop-toggle-switch {
                background: #1DB954;
            }

            .spotiloop-master-toggle.active .spotiloop-toggle-switch::after {
                transform: translateX(16px);
            }

            /* Marker Card */
            .spotiloop-card {
                background: #161822;
                border: 1px solid #222432;
                border-radius: 10px;
                padding: 10px;
                margin-bottom: 10px;
            }

            .spotiloop-card-top {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 6px;
            }

            .spotiloop-card-label {
                font-size: 11px;
                font-weight: 800;
                text-transform: uppercase;
                letter-spacing: 0.8px;
            }

            .spotiloop-jump-btn {
                background: rgba(255, 255, 255, 0.08);
                border: 1px solid rgba(255, 255, 255, 0.12);
                color: #D0D0E0;
                border-radius: 6px;
                padding: 2px 7px;
                font-size: 10px;
                font-weight: 700;
                cursor: pointer;
                transition: all 0.15s;
            }

            .spotiloop-jump-btn:hover {
                background: rgba(255, 255, 255, 0.16);
                color: #ffffff;
            }

            .spotiloop-time-input {
                width: 100%;
                background: #0B0C12;
                border: 1px solid #1E202C;
                border-radius: 8px;
                color: #ffffff;
                text-align: center;
                font-family: monospace;
                font-size: 16px;
                font-weight: 800;
                padding: 6px;
                box-sizing: border-box;
                outline: none;
                margin-bottom: 8px;
                transition: border-color 0.15s;
            }

            .spotiloop-time-input:focus {
                border-color: #1DB954;
            }

            .spotiloop-btn-row {
                display: flex;
                gap: 5px;
                margin-bottom: 5px;
            }

            .spotiloop-set-current-btn {
                width: 100%;
                padding: 6px;
                border-radius: 8px;
                font-size: 11px;
                font-weight: 800;
                cursor: pointer;
                border: none;
                margin-bottom: 6px;
                transition: filter 0.15s;
            }

            .spotiloop-set-current-btn:hover {
                filter: brightness(1.2);
            }

            .spotiloop-nudge-btn {
                flex: 1;
                background: #1C1E2A;
                border: 1px solid #282C3D;
                color: #C2C5D6;
                padding: 4px;
                border-radius: 6px;
                font-size: 10.5px;
                font-weight: 700;
                font-family: monospace;
                cursor: pointer;
                text-align: center;
                transition: all 0.15s;
            }

            .spotiloop-nudge-btn:hover {
                background: #252839;
                color: #ffffff;
                border-color: #3B415A;
            }

            .spotiloop-footer {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-top: 10px;
                padding-top: 10px;
                border-top: 1px solid #1E202C;
                font-size: 10.5px;
                color: #72768E;
            }

            .spotiloop-clear-btn {
                background: transparent;
                border: none;
                color: #F43F5E;
                font-size: 11px;
                font-weight: 700;
                cursor: pointer;
                padding: 2px 6px;
                border-radius: 4px;
            }

            .spotiloop-clear-btn:hover {
                background: rgba(244, 63, 94, 0.12);
            }

            /* Context Menu Dropdown */
            #spotiloop-context-menu {
                position: fixed;
                background: #181922;
                border: 1px solid #2B2D3C;
                border-radius: 8px;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.8);
                padding: 5px;
                min-width: 190px;
                z-index: 1000000;
                display: none;
            }

            .spotiloop-context-item {
                padding: 8px 12px;
                font-size: 12.5px;
                font-weight: 600;
                color: #E2E4EE;
                border-radius: 6px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: space-between;
                transition: background 0.15s;
            }

            .spotiloop-context-item:hover {
                background: #272A3B;
                color: #ffffff;
            }

            .spotiloop-context-divider {
                height: 1px;
                background: #262837;
                margin: 4px 0;
            }
        `;
        document.head.appendChild(style);
    }

    // ========================================================================
    // 4. TIMELINE MARKERS & INTERACTION (SCRUBBER BAR)
    // ========================================================================
    function setupTimelineScrubber() {
        // Find the playback progress bar container with comprehensive fallbacks
        const progressContainer = document.querySelector(
            '.playback-bar, [data-testid="playback-progressbar"], [class*="playback-bar"], [class*="playbackBar"], [data-testid="progress-bar"]'
        );

        if (!progressContainer) return;

        // Find the actual track inside the progress bar container
        const track = progressContainer.querySelector(
            '[data-testid="progress-bar"], [class*="progress-bar"], .x-progressBar-progressBar, .x-progressBar-sliderArea'
        ) || progressContainer;

        let timelineOverlay = track.querySelector('.spotiloop-timeline-container');
        if (!timelineOverlay) {
            timelineOverlay = document.createElement('div');
            timelineOverlay.className = 'spotiloop-timeline-container';
            track.style.position = 'relative';
            track.appendChild(timelineOverlay);

            timelineOverlay.innerHTML = `
                <div class="spotiloop-highlight-zone" id="spotiloop-zone" style="display: none;"></div>
                <div class="spotiloop-pin spotiloop-pin-a" id="spotiloop-pin-a" style="display: none;" title="Point A">A</div>
                <div class="spotiloop-pin spotiloop-pin-b" id="spotiloop-pin-b" style="display: none;" title="Point B">B</div>
            `;

            const pinA = timelineOverlay.querySelector('#spotiloop-pin-a');
            const pinB = timelineOverlay.querySelector('#spotiloop-pin-b');

            attachPinDrag(pinA, 'A', track);
            attachPinDrag(pinB, 'B', track);

            pinA.addEventListener('click', (e) => {
                e.stopPropagation();
                if (state.pointA != null) Spicetify.Player.seek(state.pointA);
            });

            pinB.addEventListener('click', (e) => {
                e.stopPropagation();
                if (state.pointB != null) Spicetify.Player.seek(state.pointB);
            });
        }

        updateTimeline();
    }

    function attachPinDrag(pin, type, container) {
        let isDragging = false;

        pin.addEventListener('mousedown', (e) => {
            e.stopPropagation();
            e.preventDefault();
            isDragging = true;
            state.dragging = type;
            document.body.style.userSelect = 'none';

            function onMouseMove(moveEvent) {
                if (!isDragging) return;
                const rect = container.getBoundingClientRect();
                const clientX = moveEvent.clientX;
                const clampedX = Math.max(rect.left, Math.min(rect.right, clientX));
                const pct = (clampedX - rect.left) / rect.width;
                const duration = Spicetify.Player.getDuration();
                if (!duration) return;

                const newMs = Math.round(pct * duration);
                if (type === 'A') {
                    state.pointA = newMs;
                    if (state.pointB != null && state.pointA >= state.pointB) {
                        state.pointB = Math.min(duration, state.pointA + 1000);
                    }
                } else {
                    state.pointB = newMs;
                    if (state.pointA != null && state.pointB <= state.pointA) {
                        state.pointA = Math.max(0, state.pointB - 1000);
                    }
                }
                updateAll();
            }

            function onMouseUp() {
                if (isDragging) {
                    isDragging = false;
                    state.dragging = null;
                    document.body.style.userSelect = '';
                    window.removeEventListener('mousemove', onMouseMove);
                    window.removeEventListener('mouseup', onMouseUp);
                    saveCurrentTrackLoop();
                }
            }

            window.addEventListener('mousemove', onMouseMove);
            window.addEventListener('mouseup', onMouseUp);
        });
    }

    function updateTimeline() {
        const zone = document.getElementById('spotiloop-zone');
        const pinA = document.getElementById('spotiloop-pin-a');
        const pinB = document.getElementById('spotiloop-pin-b');
        if (!zone || !pinA || !pinB) return;

        const duration = Spicetify.Player.getDuration();
        if (!duration || duration <= 0) {
            zone.style.display = 'none';
            pinA.style.display = 'none';
            pinB.style.display = 'none';
            return;
        }

        if (state.pointA != null) {
            const pctA = Math.max(0, Math.min(100, (state.pointA / duration) * 100));
            pinA.style.left = `${pctA}%`;
            pinA.style.display = 'flex';
            pinA.title = `Point A: ${formatTime(state.pointA)}`;
        } else {
            pinA.style.display = 'none';
        }

        if (state.pointB != null) {
            const pctB = Math.max(0, Math.min(100, (state.pointB / duration) * 100));
            pinB.style.left = `${pctB}%`;
            pinB.style.display = 'flex';
            pinB.title = `Point B: ${formatTime(state.pointB)}`;
        } else {
            pinB.style.display = 'none';
        }

        if (state.pointA != null && state.pointB != null && state.pointB > state.pointA) {
            const leftPct = (state.pointA / duration) * 100;
            const widthPct = ((state.pointB - state.pointA) / duration) * 100;
            zone.style.left = `${leftPct}%`;
            zone.style.width = `${widthPct}%`;
            zone.style.display = 'block';
            zone.style.opacity = state.enabled ? '1' : '0.4';
        } else {
            zone.style.display = 'none';
        }
    }

    // ========================================================================
    // 5. FLOATING MINI-FLYOUT PANEL
    // ========================================================================
    function createFlyout() {
        if (document.getElementById('spotiloop-flyout')) return;

        const flyout = document.createElement('div');
        flyout.id = 'spotiloop-flyout';
        flyout.innerHTML = `
            <div class="spotiloop-header">
                <div class="spotiloop-title">
                    <span style="color:#1DB954; display:flex;">${ICON_LOOP}</span>
                    <span>SpotiLoop Studio</span>
                </div>
                <div class="spotiloop-badge" id="spotiloop-count-badge">0 loops</div>
            </div>

            <!-- Master Toggle -->
            <div class="spotiloop-master-toggle" id="spotiloop-toggle-btn">
                <span style="font-size: 13px; font-weight: 700;">Loop Section</span>
                <div class="spotiloop-toggle-switch"></div>
            </div>

            <!-- Point A Card -->
            <div class="spotiloop-card">
                <div class="spotiloop-card-top">
                    <span class="spotiloop-card-label" style="color: #1DB954;">● Point A (Start)</span>
                    <button class="spotiloop-jump-btn" id="spotiloop-jump-a">Jump ➔</button>
                </div>
                <input type="text" class="spotiloop-time-input" id="spotiloop-input-a" placeholder="00:00.0" />
                <button class="spotiloop-set-current-btn" id="spotiloop-set-a" style="background: rgba(29, 185, 84, 0.18); color: #1DB954; border: 1px solid rgba(29, 185, 84, 0.35);">
                    🎯 Set Current Position
                </button>
                <div class="spotiloop-btn-row">
                    <button class="spotiloop-nudge-btn" data-nudge-a="-1000">-1.0s</button>
                    <button class="spotiloop-nudge-btn" data-nudge-a="1000">+1.0s</button>
                </div>
                <div class="spotiloop-btn-row">
                    <button class="spotiloop-nudge-btn" data-nudge-a="-100">-0.1s</button>
                    <button class="spotiloop-nudge-btn" data-nudge-a="100">+0.1s</button>
                </div>
            </div>

            <!-- Point B Card -->
            <div class="spotiloop-card">
                <div class="spotiloop-card-top">
                    <span class="spotiloop-card-label" style="color: #F43F5E;">● Point B (End)</span>
                    <button class="spotiloop-jump-btn" id="spotiloop-jump-b">Jump ➔</button>
                </div>
                <input type="text" class="spotiloop-time-input" id="spotiloop-input-b" placeholder="00:00.0" />
                <button class="spotiloop-set-current-btn" id="spotiloop-set-b" style="background: rgba(244, 63, 94, 0.18); color: #F43F5E; border: 1px solid rgba(244, 63, 94, 0.35);">
                    🎯 Set Current Position
                </button>
                <div class="spotiloop-btn-row">
                    <button class="spotiloop-nudge-btn" data-nudge-b="-1000">-1.0s</button>
                    <button class="spotiloop-nudge-btn" data-nudge-b="1000">+1.0s</button>
                </div>
                <div class="spotiloop-btn-row">
                    <button class="spotiloop-nudge-btn" data-nudge-b="-100">-0.1s</button>
                    <button class="spotiloop-nudge-btn" data-nudge-b="100">+0.1s</button>
                </div>
            </div>

            <div class="spotiloop-footer">
                <span>Hotkeys: <b>[</b> A | <b>]</b> B | <b>\\</b> Toggle</span>
                <button class="spotiloop-clear-btn" id="spotiloop-clear-btn">Clear</button>
            </div>
        `;

        document.body.appendChild(flyout);

        // Bind Flyout Controls
        const toggleBtn = flyout.querySelector('#spotiloop-toggle-btn');
        toggleBtn.addEventListener('click', toggleLoop);

        const inputA = flyout.querySelector('#spotiloop-input-a');
        const inputB = flyout.querySelector('#spotiloop-input-b');

        inputA.addEventListener('input', (e) => {
            const ms = parseTimeToMs(e.target.value);
            if (ms != null) {
                state.pointA = ms;
                updateTimeline();
                saveCurrentTrackLoop();
            }
        });
        inputA.addEventListener('blur', () => {
            inputA.value = state.pointA != null ? formatTime(state.pointA) : '';
        });
        inputA.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') inputA.blur();
        });

        inputB.addEventListener('input', (e) => {
            const ms = parseTimeToMs(e.target.value);
            if (ms != null) {
                state.pointB = ms;
                updateTimeline();
                saveCurrentTrackLoop();
            }
        });
        inputB.addEventListener('blur', () => {
            inputB.value = state.pointB != null ? formatTime(state.pointB) : '';
        });
        inputB.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') inputB.blur();
        });

        flyout.querySelector('#spotiloop-set-a').addEventListener('click', () => {
            const ms = Math.round(Spicetify.Player.getProgress());
            state.pointA = ms;
            if (state.pointB != null && state.pointB <= state.pointA) {
                state.pointB = state.pointA + 5000;
            }
            Spicetify.showNotification(`SpotiLoop: Point A set to ${formatTime(state.pointA)}`);
            updateAll();
            saveCurrentTrackLoop();
        });

        flyout.querySelector('#spotiloop-set-b').addEventListener('click', () => {
            const ms = Math.round(Spicetify.Player.getProgress());
            state.pointB = ms;
            if (state.pointA != null && state.pointA >= state.pointB) {
                state.pointA = Math.max(0, state.pointB - 5000);
            }
            Spicetify.showNotification(`SpotiLoop: Point B set to ${formatTime(state.pointB)}`);
            updateAll();
            saveCurrentTrackLoop();
        });

        flyout.querySelector('#spotiloop-jump-a').addEventListener('click', () => {
            if (state.pointA != null) Spicetify.Player.seek(state.pointA);
        });

        flyout.querySelector('#spotiloop-jump-b').addEventListener('click', () => {
            if (state.pointB != null) Spicetify.Player.seek(state.pointB);
        });

        flyout.querySelectorAll('[data-nudge-a]').forEach(btn => {
            btn.addEventListener('click', () => {
                const diff = parseInt(btn.getAttribute('data-nudge-a'), 10);
                if (state.pointA == null) state.pointA = Math.round(Spicetify.Player.getProgress());
                state.pointA = Math.max(0, state.pointA + diff);
                updateAll();
                saveCurrentTrackLoop();
            });
        });

        flyout.querySelectorAll('[data-nudge-b]').forEach(btn => {
            btn.addEventListener('click', () => {
                const diff = parseInt(btn.getAttribute('data-nudge-b'), 10);
                if (state.pointB == null) state.pointB = Math.round(Spicetify.Player.getProgress());
                state.pointB = Math.max(0, state.pointB + diff);
                updateAll();
                saveCurrentTrackLoop();
            });
        });

        flyout.querySelector('#spotiloop-clear-btn').addEventListener('click', () => {
            state.pointA = null;
            state.pointB = null;
            state.enabled = false;
            state.loopCount = 0;
            Spicetify.showNotification('SpotiLoop: Markers cleared');
            updateAll();
            saveCurrentTrackLoop();
        });

        // Close when clicking outside
        window.addEventListener('click', (e) => {
            if (!state.flyoutOpen) return;
            const flyoutEl = document.getElementById('spotiloop-flyout');
            const buttonEl = playbarButton?.element || document.getElementById('spotiloop-custom-btn');
            if (flyoutEl && !flyoutEl.contains(e.target) && buttonEl && !buttonEl.contains(e.target)) {
                closeFlyout();
            }
        });
    }

    function toggleFlyout() {
        const flyout = document.getElementById('spotiloop-flyout');
        if (!flyout) return;
        state.flyoutOpen = !state.flyoutOpen;
        if (state.flyoutOpen) {
            positionFlyout();
            flyout.style.display = 'block';
            updateFlyout();
        } else {
            flyout.style.display = 'none';
        }
    }

    function closeFlyout() {
        const flyout = document.getElementById('spotiloop-flyout');
        if (flyout) flyout.style.display = 'none';
        state.flyoutOpen = false;
    }

    function positionFlyout() {
        const flyout = document.getElementById('spotiloop-flyout');
        const btn = playbarButton?.element || document.getElementById('spotiloop-custom-btn');
        if (!flyout || !btn) return;

        const rect = btn.getBoundingClientRect();
        const rightOffset = Math.max(16, window.innerWidth - rect.right - 20);
        const bottomOffset = window.innerHeight - rect.top + 12;

        flyout.style.right = `${rightOffset}px`;
        flyout.style.bottom = `${bottomOffset}px`;
    }

    function updateFlyout() {
        const flyout = document.getElementById('spotiloop-flyout');
        if (!flyout) return;

        const toggleBtn = flyout.querySelector('#spotiloop-toggle-btn');
        if (state.enabled) {
            toggleBtn.classList.add('active');
        } else {
            toggleBtn.classList.remove('active');
        }

        const inputA = flyout.querySelector('#spotiloop-input-a');
        const inputB = flyout.querySelector('#spotiloop-input-b');
        if (document.activeElement !== inputA) {
            inputA.value = state.pointA != null ? formatTime(state.pointA) : '';
        }
        if (document.activeElement !== inputB) {
            inputB.value = state.pointB != null ? formatTime(state.pointB) : '';
        }

        updateLoopCountDisplay();
    }

    function updateLoopCountDisplay() {
        const badge = document.getElementById('spotiloop-count-badge');
        if (badge) {
            badge.innerText = `${state.loopCount} loop${state.loopCount === 1 ? '' : 's'}`;
        }
    }

    // ========================================================================
    // 6. CONTEXT MENU (RIGHT-CLICK)
    // ========================================================================
    function createContextMenu() {
        if (document.getElementById('spotiloop-context-menu')) return;
        const menu = document.createElement('div');
        menu.id = 'spotiloop-context-menu';
        menu.innerHTML = `
            <div class="spotiloop-context-item" id="spotiloop-cm-set-a">Set Point A (Start)</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-set-b">Set Point B (End)</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-jump-a">Jump to Point A</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-jump-b">Jump to Point B</div>
            <div class="spotiloop-context-divider"></div>
            <div class="spotiloop-context-item" id="spotiloop-cm-toggle">Toggle Loop (ON/OFF)</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-clear" style="color: #F43F5E;">Clear Markers</div>
        `;
        document.body.appendChild(menu);

        menu.querySelector('#spotiloop-cm-set-a').addEventListener('click', () => {
            state.pointA = Math.round(Spicetify.Player.getProgress());
            Spicetify.showNotification(`SpotiLoop: Point A set to ${formatTime(state.pointA)}`);
            updateAll();
            saveCurrentTrackLoop();
            closeContextMenu();
        });

        menu.querySelector('#spotiloop-cm-set-b').addEventListener('click', () => {
            state.pointB = Math.round(Spicetify.Player.getProgress());
            Spicetify.showNotification(`SpotiLoop: Point B set to ${formatTime(state.pointB)}`);
            updateAll();
            saveCurrentTrackLoop();
            closeContextMenu();
        });

        menu.querySelector('#spotiloop-cm-jump-a').addEventListener('click', () => {
            if (state.pointA != null) Spicetify.Player.seek(state.pointA);
            closeContextMenu();
        });

        menu.querySelector('#spotiloop-cm-jump-b').addEventListener('click', () => {
            if (state.pointB != null) Spicetify.Player.seek(state.pointB);
            closeContextMenu();
        });

        menu.querySelector('#spotiloop-cm-toggle').addEventListener('click', () => {
            toggleLoop();
            closeContextMenu();
        });

        menu.querySelector('#spotiloop-cm-clear').addEventListener('click', () => {
            state.pointA = null;
            state.pointB = null;
            state.enabled = false;
            state.loopCount = 0;
            Spicetify.showNotification('SpotiLoop: Markers cleared');
            updateAll();
            saveCurrentTrackLoop();
            closeContextMenu();
        });

        window.addEventListener('click', (e) => {
            if (!state.contextMenuOpen) return;
            const menuEl = document.getElementById('spotiloop-context-menu');
            if (menuEl && !menuEl.contains(e.target)) {
                closeContextMenu();
            }
        });
    }

    function openContextMenu(x, y) {
        const menu = document.getElementById('spotiloop-context-menu');
        if (!menu) return;
        state.contextMenuOpen = true;
        menu.style.display = 'block';

        const menuWidth = 200;
        const menuHeight = 180;
        const posX = (x + menuWidth > window.innerWidth) ? (x - menuWidth) : x;
        const posY = (y + menuHeight > window.innerHeight) ? (y - menuHeight) : y;

        menu.style.left = `${posX}px`;
        menu.style.top = `${posY}px`;
    }

    function closeContextMenu() {
        const menu = document.getElementById('spotiloop-context-menu');
        if (menu) menu.style.display = 'none';
        state.contextMenuOpen = false;
    }

    // ========================================================================
    // 7. PLAYBAR BUTTON & ACTIONS
    // ========================================================================
    function toggleLoop() {
        if (state.pointA == null && state.pointB == null) {
            state.pointA = Math.round(Spicetify.Player.getProgress());
            state.pointB = Math.min(Spicetify.Player.getDuration(), state.pointA + 10000);
            state.enabled = true;
            state.loopCount = 0;
            Spicetify.showNotification(`SpotiLoop: Loop active (${formatTime(state.pointA)} ➔ ${formatTime(state.pointB)})`);
        } else if (state.pointA == null) {
            state.pointA = 0;
            state.enabled = true;
            Spicetify.showNotification(`SpotiLoop: Loop enabled`);
        } else if (state.pointB == null) {
            state.pointB = Spicetify.Player.getDuration();
            state.enabled = true;
            Spicetify.showNotification(`SpotiLoop: Loop enabled`);
        } else {
            state.enabled = !state.enabled;
            Spicetify.showNotification(state.enabled ? 'SpotiLoop: Loop Enabled' : 'SpotiLoop: Loop Disabled');
        }

        updateAll();
        saveCurrentTrackLoop();
    }

    function updateAll() {
        const btn = playbarButton?.element || document.getElementById('spotiloop-custom-btn');
        if (btn) {
            if (state.enabled) {
                btn.classList.add('spotiloop-btn-active');
            } else {
                btn.classList.remove('spotiloop-btn-active');
            }

            const tooltip = `SpotiLoop: ${state.enabled ? 'ACTIVE' : 'OFF'} [${formatTime(state.pointA)} ➔ ${formatTime(state.pointB)}]`;
            if (playbarButton?.tippy) {
                playbarButton.tippy.setContent(tooltip);
            } else {
                btn.setAttribute('title', tooltip);
            }
        }

        updateTimeline();
        updateFlyout();
    }

    function ensurePlaybarButtonInDOM() {
        let btn = playbarButton?.element || document.getElementById('spotiloop-custom-btn');

        if (!btn) {
            btn = document.createElement('button');
            btn.id = 'spotiloop-custom-btn';
            btn.className = 'spotiloop-playbar-btn';
            btn.innerHTML = ICON_LOOP;
            btn.setAttribute('title', 'SpotiLoop A-B Looper');

            btn.addEventListener('click', (e) => {
                if (e.altKey) {
                    toggleLoop();
                } else {
                    toggleFlyout();
                }
            });

            btn.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                e.stopPropagation();
                closeFlyout();
                openContextMenu(e.clientX, e.clientY);
            });

            btn.addEventListener('auxclick', (e) => {
                if (e.button === 1) {
                    e.preventDefault();
                    toggleLoop();
                }
            });
        }

        if (document.body.contains(btn)) return;

        // Try placing right before lyrics button, or inside extraControls container
        const lyricsBtn = document.querySelector(
            'button[data-testid="lyrics-button"], button[aria-label*="lyrics" i], button[aria-label*="Lyrics" i], .main-nowPlayingBar-lyricsButton'
        );

        if (lyricsBtn && lyricsBtn.parentNode) {
            lyricsBtn.parentNode.insertBefore(btn, lyricsBtn);
            return;
        }

        const extraControls = document.querySelector(
            '.main-nowPlayingBar-right > div, .main-nowPlayingBar-extraControls, [class*="nowPlayingBar-right"], [class*="extraControls"], footer [data-testid="now-playing-widget"]'
        );

        if (extraControls) {
            extraControls.prepend(btn);
        }
    }

    function setupPlaybarButton() {
        try {
            playbarButton = new Spicetify.Playbar.Button(
                'SpotiLoop A-B Looper',
                ICON_LOOP,
                () => toggleFlyout(),
                false,
                false,
                true
            );
        } catch (e) {}

        ensurePlaybarButtonInDOM();
    }

    // ========================================================================
    // 8. KEYBOARD SHORTCUTS
    // ========================================================================
    function setupKeyboardShortcuts() {
        window.addEventListener('keydown', (e) => {
            const target = e.target;
            // Never trigger if user is actively typing in a search bar or text field
            if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) {
                return;
            }

            // '[' sets Point A
            if (e.key === '[') {
                e.preventDefault();
                const ms = Math.round(Spicetify.Player.getProgress());
                state.pointA = ms;
                if (state.pointB != null && state.pointB <= state.pointA) {
                    state.pointB = state.pointA + 5000;
                }
                Spicetify.showNotification(`SpotiLoop: Point A set to ${formatTime(state.pointA)}`);
                updateAll();
                saveCurrentTrackLoop();
            }

            // ']' sets Point B
            else if (e.key === ']') {
                e.preventDefault();
                const ms = Math.round(Spicetify.Player.getProgress());
                state.pointB = ms;
                if (state.pointA != null && state.pointA >= state.pointB) {
                    state.pointA = Math.max(0, state.pointB - 5000);
                }
                Spicetify.showNotification(`SpotiLoop: Point B set to ${formatTime(state.pointB)}`);
                updateAll();
                saveCurrentTrackLoop();
            }

            // '\' or Alt+L toggles loop
            else if (e.key === '\\' || (e.altKey && (e.key === 'l' || e.key === 'L'))) {
                e.preventDefault();
                toggleLoop();
            }

            // Shift + '[' jumps to Point A
            else if (e.shiftKey && e.key === '{') {
                e.preventDefault();
                if (state.pointA != null) Spicetify.Player.seek(state.pointA);
            }

            // Shift + ']' jumps to Point B
            else if (e.shiftKey && e.key === '}') {
                e.preventDefault();
                if (state.pointB != null) Spicetify.Player.seek(state.pointB);
            }
        });
    }

    // ========================================================================
    // 9. SONG CHANGE LISTENER (AUTO RESTORE PER-SONG LOOPS)
    // ========================================================================
    function setupSongChangeListener() {
        Spicetify.Player.addEventListener('songchange', (event) => {
            const newUri = event?.data?.item?.uri || Spicetify.Player.data?.item?.uri;
            if (newUri !== state.activeTrackUri) {
                state.activeTrackUri = newUri;
                loadTrackLoop(newUri);
                setupTimelineScrubber();
                ensurePlaybarButtonInDOM();
            }
        });
    }

    // Observer to re-attach timeline pins and playbar button whenever Spotify navigates
    function observeDOM() {
        timelineObserver = new MutationObserver(() => {
            setupTimelineScrubber();
            ensurePlaybarButtonInDOM();
        });
        const target = document.querySelector('.Root__now-playing-bar') || document.body;
        timelineObserver.observe(target, { childList: true, subtree: true });
    }

    // ========================================================================
    // 10. INITIALIZATION
    // ========================================================================
    injectStyles();
    createFlyout();
    createContextMenu();
    setupPlaybarButton();
    setupTimelineScrubber();
    setupKeyboardShortcuts();
    setupSongChangeListener();
    observeDOM();
    startEngine();

    // Load initial track state if something is currently playing
    const currentUri = getTrackUri();
    if (currentUri) {
        state.activeTrackUri = currentUri;
        loadTrackLoop(currentUri);
    }

    console.log('[SpotiLoop] Extension initialized successfully with 0ms local loop engine!');
})();
