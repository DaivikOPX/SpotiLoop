// ============================================================================
// SpotiLoop - High-Precision Minimalist Spotify A-B Looper for Spicetify
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

    // Minimal Vector Icons
    const ICON_LOOP = `<svg role="img" height="16" width="16" viewBox="0 0 16 16" fill="currentColor">
        <path d="M5.5 5H10v1.5l3.5-2-3.5-2V4H5.5C3 4 1 6 1 8.5c0 .6.1 1.2.4 1.8l.9-.5C2.1 9.4 2 9 2 8.5 2 6.6 3.6 5 5.5 5zm9.1 1.7l-.9.5c.2.4.3.8.3 1.3 0 1.9-1.6 3.5-3.5 3.5H6v-1.5l-3.5 2 3.5 2V13h4.5C13 13 15 11 15 8.5c0-.6-.1-1.2-.4-1.8z"/>
    </svg>`;

    const ICON_SET = `<svg viewBox="0 0 16 16" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
        <circle cx="8" cy="8" r="6"/>
        <circle cx="8" cy="8" r="1.5" fill="currentColor"/>
        <line x1="8" y1="0.5" x2="8" y2="3"/>
        <line x1="8" y1="13" x2="8" y2="15.5"/>
        <line x1="0.5" y1="8" x2="3" y2="8"/>
        <line x1="13" y1="8" x2="15.5" y2="8"/>
    </svg>`;

    const ICON_JUMP = `<svg viewBox="0 0 16 16" width="11" height="11" fill="currentColor">
        <polygon points="4,2.5 13.5,8 4,13.5"/>
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
    // 3. MINIMALIST FROSTED GLASS STYLING
    // ========================================================================
    function injectStyles() {
        if (document.getElementById('spotiloop-styles')) return;
        const style = document.createElement('style');
        style.id = 'spotiloop-styles';
        style.innerHTML = `
            /* Playbar Looper Button - Pixel-Perfect Centering & Spotify Encore Styling */
            .spotiloop-playbar-btn,
            button.main-genericButton-button.spotiloop-playbar-btn,
            button.main-genericButton-button[data-spotiloop="true"],
            #spotiloop-custom-btn {
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                width: 32px !important;
                height: 32px !important;
                min-width: 32px !important;
                min-height: 32px !important;
                padding: 0 !important;
                margin: 0 !important;
                border: none !important;
                background: transparent !important;
                color: var(--spice-subtext, #a7a7a7) !important;
                cursor: pointer !important;
                position: relative !important;
                box-sizing: border-box !important;
                vertical-align: middle !important;
                transition: color 0.15s ease, transform 0.15s ease, filter 0.15s ease !important;
            }

            .spotiloop-playbar-btn:hover,
            button.main-genericButton-button[data-spotiloop="true"]:hover,
            #spotiloop-custom-btn:hover {
                color: var(--spice-text, #ffffff) !important;
                transform: scale(1.08) !important;
            }

            .spotiloop-playbar-btn.spotiloop-btn-active,
            button.main-genericButton-button[data-spotiloop="true"].main-genericButton-buttonActive,
            #spotiloop-custom-btn.spotiloop-btn-active {
                color: var(--spice-button, #1db954) !important;
                filter: drop-shadow(0 0 6px rgba(29, 185, 84, 0.65)) !important;
            }

            /* Force perfect geometric centering on span wrapper and SVG */
            .spotiloop-playbar-btn > span,
            button.main-genericButton-button[data-spotiloop="true"] > span,
            #spotiloop-custom-btn > span {
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                width: 16px !important;
                height: 16px !important;
                line-height: 0 !important;
                margin: 0 !important;
                padding: 0 !important;
            }

            .spotiloop-playbar-btn svg,
            button.main-genericButton-button[data-spotiloop="true"] svg,
            #spotiloop-custom-btn svg {
                display: block !important;
                width: 16px !important;
                height: 16px !important;
                min-width: 16px !important;
                min-height: 16px !important;
                margin: 0 auto !important;
                padding: 0 !important;
                vertical-align: middle !important;
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
                background: rgba(29, 185, 84, 0.32);
                border-left: 2px solid #1DB954;
                border-right: 2px solid #F43F5E;
                border-radius: 3px;
                box-shadow: 0 0 8px rgba(29, 185, 84, 0.35);
                transition: opacity 0.15s ease;
                pointer-events: none;
            }

            .spotiloop-pin {
                position: absolute;
                top: 50%;
                width: 13px;
                height: 13px;
                border-radius: 50%;
                transform: translate(-50%, -50%);
                cursor: grab;
                pointer-events: auto;
                box-shadow: 0 2px 6px rgba(0,0,0,0.7);
                transition: transform 0.1s ease;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 8px;
                font-weight: 800;
                color: #ffffff;
                user-select: none;
                z-index: 25;
            }

            .spotiloop-pin:hover {
                transform: translate(-50%, -50%) scale(1.3);
            }

            .spotiloop-pin:active {
                cursor: grabbing;
                transform: translate(-50%, -50%) scale(1.4);
            }

            .spotiloop-pin-a {
                background: #1DB954;
                border: 2px solid #ffffff;
            }

            .spotiloop-pin-b {
                background: #F43F5E;
                border: 2px solid #ffffff;
            }

            /* Sleek Frosted Glass Flyout */
            #spotiloop-flyout {
                position: fixed;
                bottom: 92px;
                right: 50px;
                width: 250px;
                background: rgba(22, 22, 26, 0.92);
                border: 1px solid rgba(255, 255, 255, 0.09);
                border-radius: 14px;
                box-shadow: 0 16px 40px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(0,0,0,0.3);
                backdrop-filter: blur(28px) saturate(190%);
                color: #ffffff;
                padding: 12px 14px;
                font-family: var(--encore-body-font-stack, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif);
                z-index: 999999;
                display: none;
                animation: spotiloop-fade 0.18s cubic-bezier(0.16, 1, 0.3, 1);
                user-select: none;
            }

            @keyframes spotiloop-fade {
                from { opacity: 0; transform: translateY(8px) scale(0.97); }
                to { opacity: 1; transform: translateY(0) scale(1); }
            }

            /* Header */
            .spotiloop-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 12px;
            }

            .spotiloop-brand {
                display: flex;
                align-items: center;
                gap: 7px;
                font-size: 12.5px;
                font-weight: 700;
                letter-spacing: -0.2px;
                color: #E6E6E6;
            }

            .spotiloop-header-right {
                display: flex;
                align-items: center;
                gap: 8px;
            }

            .spotiloop-badge {
                font-size: 10px;
                font-weight: 700;
                color: #1DB954;
                background: rgba(29, 185, 84, 0.12);
                padding: 1px 6px;
                border-radius: 8px;
            }

            /* Toggle Switch */
            .spotiloop-toggle-switch {
                position: relative;
                width: 32px;
                height: 18px;
                background: #333339;
                border-radius: 10px;
                cursor: pointer;
                transition: background 0.2s ease, box-shadow 0.2s ease;
            }

            .spotiloop-toggle-switch::after {
                content: '';
                position: absolute;
                top: 2px;
                left: 2px;
                width: 14px;
                height: 14px;
                background: #ffffff;
                border-radius: 50%;
                transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
                box-shadow: 0 1px 3px rgba(0,0,0,0.4);
            }

            .spotiloop-toggle-switch.active {
                background: #1DB954;
                box-shadow: 0 0 10px rgba(29, 185, 84, 0.45);
            }

            .spotiloop-toggle-switch.active::after {
                transform: translateX(14px);
            }

            /* Marker Section */
            .spotiloop-section {
                background: rgba(255, 255, 255, 0.035);
                border-radius: 10px;
                padding: 8px 10px;
                margin-bottom: 8px;
                border: 1px solid rgba(255, 255, 255, 0.04);
                transition: background 0.15s ease;
            }

            .spotiloop-section:hover {
                background: rgba(255, 255, 255, 0.055);
            }

            .spotiloop-row {
                display: flex;
                align-items: center;
                justify-content: space-between;
                gap: 8px;
            }

            .spotiloop-dot-label {
                width: 17px;
                height: 17px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 9px;
                font-weight: 800;
                color: #ffffff;
                flex-shrink: 0;
            }

            .spotiloop-dot-a {
                background: #1DB954;
            }

            .spotiloop-dot-b {
                background: #F43F5E;
            }

            /* Clean Modern Time Display */
            .spotiloop-time-input {
                flex: 1;
                background: transparent;
                border: none;
                color: #FFFFFF;
                font-size: 15px;
                font-weight: 700;
                letter-spacing: 0.3px;
                outline: none;
                padding: 0;
                margin: 0;
                font-family: inherit;
            }

            .spotiloop-action-icons {
                display: flex;
                align-items: center;
                gap: 4px;
            }

            .spotiloop-icon-btn {
                background: rgba(255, 255, 255, 0.06);
                border: none;
                color: #B3B3B3;
                width: 24px;
                height: 24px;
                border-radius: 6px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                transition: all 0.15s ease;
                padding: 0;
            }

            .spotiloop-icon-btn:hover {
                background: rgba(255, 255, 255, 0.14);
                color: #FFFFFF;
                transform: scale(1.05);
            }

            /* Minimalist Nudge Bar */
            .spotiloop-nudge-bar {
                display: flex;
                align-items: center;
                gap: 3px;
                margin-top: 6px;
                padding-top: 6px;
                border-top: 1px solid rgba(255, 255, 255, 0.04);
            }

            .spotiloop-nudge-pill {
                flex: 1;
                background: rgba(255, 255, 255, 0.04);
                border: none;
                color: #929298;
                padding: 2.5px 0;
                border-radius: 5px;
                font-size: 9.5px;
                font-weight: 600;
                cursor: pointer;
                text-align: center;
                transition: all 0.15s ease;
            }

            .spotiloop-nudge-pill:hover {
                background: rgba(255, 255, 255, 0.12);
                color: #FFFFFF;
            }

            /* Footer */
            .spotiloop-footer {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-top: 8px;
                padding-top: 4px;
                font-size: 10px;
                color: #6A6A74;
            }

            .spotiloop-hint {
                letter-spacing: 0.1px;
            }

            .spotiloop-clear-btn {
                background: transparent;
                border: none;
                color: #8E8E98;
                font-size: 10.5px;
                font-weight: 600;
                cursor: pointer;
                padding: 2px 4px;
                border-radius: 4px;
                transition: color 0.15s ease;
            }

            .spotiloop-clear-btn:hover {
                color: #F43F5E;
            }

            /* Context Menu Dropdown */
            #spotiloop-context-menu {
                position: fixed;
                background: rgba(24, 24, 28, 0.95);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 8px;
                box-shadow: 0 12px 32px rgba(0, 0, 0, 0.7);
                backdrop-filter: blur(20px);
                padding: 4px;
                min-width: 175px;
                z-index: 1000000;
                display: none;
            }

            .spotiloop-context-item {
                padding: 7px 10px;
                font-size: 12px;
                font-weight: 500;
                color: #D4D4D8;
                border-radius: 5px;
                cursor: pointer;
                transition: background 0.15s ease, color 0.15s ease;
            }

            .spotiloop-context-item:hover {
                background: rgba(255, 255, 255, 0.08);
                color: #FFFFFF;
            }

            .spotiloop-context-divider {
                height: 1px;
                background: rgba(255, 255, 255, 0.06);
                margin: 3px 0;
            }
        `;
        document.head.appendChild(style);
    }

    // ========================================================================
    // 4. TIMELINE MARKERS & INTERACTION (SCRUBBER BAR)
    // ========================================================================
    function setupTimelineScrubber() {
        const progressContainer = document.querySelector(
            '.playback-bar, [data-testid="playback-progressbar"], [class*="playback-bar"], [class*="playbackBar"], [data-testid="progress-bar"]'
        );

        if (!progressContainer) return;

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
            zone.style.opacity = state.enabled ? '1' : '0.35';
        } else {
            zone.style.display = 'none';
        }
    }

    // ========================================================================
    // 5. NEW MINIMALIST GLASS FLYOUT
    // ========================================================================
    function createFlyout() {
        if (document.getElementById('spotiloop-flyout')) return;

        const flyout = document.createElement('div');
        flyout.id = 'spotiloop-flyout';
        flyout.innerHTML = `
            <!-- Header -->
            <div class="spotiloop-header">
                <div class="spotiloop-brand">
                    <span style="color:#1DB954; display:flex;">${ICON_LOOP}</span>
                    <span>SpotiLoop</span>
                </div>
                <div class="spotiloop-header-right">
                    <span class="spotiloop-badge" id="spotiloop-count-badge">0x</span>
                    <div class="spotiloop-toggle-switch" id="spotiloop-toggle-btn" title="Toggle Loop (\\)"></div>
                </div>
            </div>

            <!-- Point A Section -->
            <div class="spotiloop-section">
                <div class="spotiloop-row">
                    <div class="spotiloop-dot-label spotiloop-dot-a">A</div>
                    <input type="text" class="spotiloop-time-input" id="spotiloop-input-a" placeholder="--:--.-" spellcheck="false" />
                    <div class="spotiloop-action-icons">
                        <button class="spotiloop-icon-btn" id="spotiloop-set-a" title="Set Point A to current playback position">
                            ${ICON_SET}
                        </button>
                        <button class="spotiloop-icon-btn" id="spotiloop-jump-a" title="Jump to Point A">
                            ${ICON_JUMP}
                        </button>
                    </div>
                </div>
                <div class="spotiloop-nudge-bar">
                    <button class="spotiloop-nudge-pill" data-nudge-a="-1000">-1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-a="-100">-0.1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-a="100">+0.1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-a="1000">+1s</button>
                </div>
            </div>

            <!-- Point B Section -->
            <div class="spotiloop-section">
                <div class="spotiloop-row">
                    <div class="spotiloop-dot-label spotiloop-dot-b">B</div>
                    <input type="text" class="spotiloop-time-input" id="spotiloop-input-b" placeholder="--:--.-" spellcheck="false" />
                    <div class="spotiloop-action-icons">
                        <button class="spotiloop-icon-btn" id="spotiloop-set-b" title="Set Point B to current playback position">
                            ${ICON_SET}
                        </button>
                        <button class="spotiloop-icon-btn" id="spotiloop-jump-b" title="Jump to Point B">
                            ${ICON_JUMP}
                        </button>
                    </div>
                </div>
                <div class="spotiloop-nudge-bar">
                    <button class="spotiloop-nudge-pill" data-nudge-b="-1000">-1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-b="-100">-0.1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-b="100">+0.1s</button>
                    <button class="spotiloop-nudge-pill" data-nudge-b="1000">+1s</button>
                </div>
            </div>

            <!-- Minimal Footer -->
            <div class="spotiloop-footer">
                <span class="spotiloop-hint">[ A | ] B | \\ Loop</span>
                <button class="spotiloop-clear-btn" id="spotiloop-clear-btn">Reset</button>
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
        const rightOffset = Math.max(16, window.innerWidth - rect.right - 10);
        const bottomOffset = window.innerHeight - rect.top + 10;

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
            badge.innerText = `${state.loopCount}x`;
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
            <div class="spotiloop-context-item" id="spotiloop-cm-set-a">Set Point A</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-set-b">Set Point B</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-jump-a">Jump to A</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-jump-b">Jump to B</div>
            <div class="spotiloop-context-divider"></div>
            <div class="spotiloop-context-item" id="spotiloop-cm-toggle">Toggle Loop</div>
            <div class="spotiloop-context-item" id="spotiloop-cm-clear" style="color: #F43F5E;">Reset</div>
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

        const menuWidth = 180;
        const menuHeight = 160;
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
                if (playbarButton) playbarButton.active = true;
            } else {
                btn.classList.remove('spotiloop-btn-active');
                if (playbarButton) playbarButton.active = false;
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
            btn.className = 'spotiloop-playbar-btn main-genericButton-button';
            btn.setAttribute('data-spotiloop', 'true');
            btn.innerHTML = `<span class="Wrapper-sm-only Wrapper-small-only">${ICON_LOOP}</span>`;
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

        // Tag with attribute and class for reliable CSS centering
        btn.setAttribute('data-spotiloop', 'true');
        btn.classList.add('spotiloop-playbar-btn');

        // Target the right-side extra controls flex container
        const extraControls = document.querySelector(
            '.main-nowPlayingBar-extraControls, .main-nowPlayingBar-right > div, [class*="nowPlayingBar-right"] [class*="extraControls"], .main-nowPlayingBar-right'
        );

        if (extraControls) {
            // Position on the leftmost side of the extra controls cluster (ahead of lyrics, queue, volume)
            // It automatically shifts dynamically with any added/removed extension icons
            if (extraControls.firstElementChild !== btn) {
                extraControls.prepend(btn);
            }
        }
    }

    function setupPlaybarButton() {
        try {
            playbarButton = new Spicetify.Playbar.Button(
                'SpotiLoop A-B Looper',
                'repeat',
                () => toggleFlyout(),
                false,
                false,
                true
            );

            if (playbarButton?.element) {
                playbarButton.element.setAttribute('data-spotiloop', 'true');
                playbarButton.element.classList.add('spotiloop-playbar-btn');

                playbarButton.element.addEventListener('contextmenu', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    closeFlyout();
                    openContextMenu(e.clientX, e.clientY);
                });

                playbarButton.element.addEventListener('auxclick', (e) => {
                    if (e.button === 1) {
                        e.preventDefault();
                        toggleLoop();
                    }
                });
            }
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
