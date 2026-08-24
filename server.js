const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Runtime Encrypted Key Resolver
function _resolveClientId() {
  const _k = [106,60,106,56,104,60,106,110,104,111,110,105,110,109,104,105,99,105,110,111,108,99,109,60,105,99,109,111,107,107,98,99];
  return String.fromCharCode(..._k.map(c => c ^ 0x5a));
}

// Simple .env Loader
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const line of lines) {
      const match = line.match(/^\s*([\w_]+)\s*=\s*(.*)?\s*$/);
      if (match) {
        const key = match[1];
        let val = (match[2] || '').trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        }
        process.env[key] = val;
      }
    }
  }
}
loadEnv();

const PORT = parseInt(process.env.PORT || '8888', 10);
const HOST = process.env.HOST || '127.0.0.1';
const HTML_FILE = path.join(__dirname, 'instant_looper.html');
const SESSION_FILE = path.join(__dirname, '.spotify_session.json');

// State Manager
let sharedState = {
  isLoopActive: false,
  pointA: null,
  pointB: null,
  durationMs: 0,
  lastProgressMs: 0,
  lastSyncTime: Date.now(),
  isPlaying: false,
  isIdle: true,
  currentTrackName: null,
  currentArtistName: null,
  albumArtUrl: null,
  accessToken: null,
  refreshToken: null,
  tokenExpiresAt: 0,
  clientId: process.env.SPOTIFY_CLIENT_ID || _resolveClientId(),
  activeDeviceId: null,
  activeDeviceName: null,
  seekLeadOffsetMs: 120,
  loopCount: 0,
  lastSeekDispatched: 0,
  seekLockoutUntil: 0
};

// Load saved session on server startup
function loadSessionFromFile() {
  try {
    if (fs.existsSync(SESSION_FILE)) {
      const data = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
      if (data.accessToken) sharedState.accessToken = data.accessToken;
      if (data.refreshToken) sharedState.refreshToken = data.refreshToken;
      if (data.tokenExpiresAt) sharedState.tokenExpiresAt = data.tokenExpiresAt;
      if (data.seekLeadOffsetMs) sharedState.seekLeadOffsetMs = data.seekLeadOffsetMs;
      console.log('[Session] Loaded persistent Spotify session from .spotify_session.json');
      // Proactively refresh token if expired
      if (sharedState.refreshToken && Date.now() >= (sharedState.tokenExpiresAt - 60000)) {
        refreshSpotifyToken();
      }
    }
  } catch (e) {
    console.error('[Session] Could not read .spotify_session.json:', e.message);
  }
}

// Save session persistently
function saveSessionToFile() {
  try {
    const data = {
      accessToken: sharedState.accessToken,
      refreshToken: sharedState.refreshToken,
      tokenExpiresAt: sharedState.tokenExpiresAt,
      seekLeadOffsetMs: sharedState.seekLeadOffsetMs,
      savedAt: new Date().toISOString()
    };
    fs.writeFileSync(SESSION_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error('[Session] Could not save .spotify_session.json:', e.message);
  }
}

function clearSessionFile() {
  try {
    if (fs.existsSync(SESSION_FILE)) {
      fs.unlinkSync(SESSION_FILE);
    }
  } catch (_) {}
}

// Spotify API Request Helper
function spotifyApiRequest(method, endpoint, token, bodyData = null) {
  return new Promise((resolve, reject) => {
    if (!token) return reject(new Error('No token provided'));

    const parsedUrl = new URL(endpoint, 'https://api.spotify.com');
    const options = {
      hostname: parsedUrl.hostname,
      port: 443,
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    if (bodyData) {
      const dataStr = JSON.stringify(bodyData);
      options.headers['Content-Length'] = Buffer.byteLength(dataStr);
    } else {
      options.headers['Content-Length'] = 0;
    }

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 204) {
          resolve({ status: 204, data: null });
        } else if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null });
          } catch (e) {
            resolve({ status: res.statusCode, data: null });
          }
        } else {
          resolve({ status: res.statusCode, error: data });
        }
      });
    });

    req.on('error', (err) => reject(err));
    if (bodyData) req.write(JSON.stringify(bodyData));
    req.end();
  });
}

// Token Refresh Handler
async function refreshSpotifyToken() {
  if (!sharedState.refreshToken || !sharedState.clientId) return null;

  return new Promise((resolve) => {
    const postData = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: sharedState.refreshToken,
      client_id: sharedState.clientId
    }).toString();

    const options = {
      hostname: 'accounts.spotify.com',
      port: 443,
      path: '/api/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const parsed = JSON.parse(body);
            sharedState.accessToken = parsed.access_token;
            if (parsed.refresh_token) sharedState.refreshToken = parsed.refresh_token;
            sharedState.tokenExpiresAt = Date.now() + (parsed.expires_in - 60) * 1000;
            saveSessionToFile();
            console.log('[Auth] Refreshed Spotify token and saved to .spotify_session.json');
            resolve(parsed.access_token);
          } catch (e) {
            resolve(null);
          }
        } else {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
    req.write(postData);
    req.end();
  });
}

// Execute Precise Seek
async function executeSeek(targetMs) {
  if (!sharedState.accessToken) return false;

  // Auto-refresh token if close to expiry
  if (Date.now() >= sharedState.tokenExpiresAt && sharedState.refreshToken) {
    await refreshSpotifyToken();
  }

  const target = Math.max(0, Math.round(targetMs));
  let endpoint = `/v1/me/player/seek?position_ms=${target}`;
  if (sharedState.activeDeviceId) {
    endpoint += `&device_id=${encodeURIComponent(sharedState.activeDeviceId)}`;
  }

  try {
    const res = await spotifyApiRequest('PUT', endpoint, sharedState.accessToken);
    if (res.status === 204 || res.status === 200) {
      return true;
    } else if (res.status === 401 && sharedState.refreshToken) {
      const newToken = await refreshSpotifyToken();
      if (newToken) {
        await spotifyApiRequest('PUT', endpoint, newToken);
        return true;
      }
    }
  } catch (err) {
    console.error('[Seek Error]', err.message);
  }
  return false;
}

// Central High-Precision Native OS Heartbeat Ticker (25ms)
setInterval(async () => {
  if (!sharedState.isLoopActive || !sharedState.accessToken || !sharedState.isPlaying) {
    return;
  }
  const { pointA, pointB, durationMs, lastProgressMs, lastSyncTime, seekLeadOffsetMs } = sharedState;
  if (pointA === null || pointB === null || durationMs <= 0 || pointA >= pointB) return;

  const now = Date.now();
  const elapsed = now - lastSyncTime;
  const currentEst = lastProgressMs + elapsed;
  const triggerPoint = pointB - seekLeadOffsetMs;

  if (currentEst >= triggerPoint) {
    if (now - sharedState.lastSeekDispatched > 350) {
      sharedState.lastSeekDispatched = now;
      sharedState.seekLockoutUntil = now + 1200;
      sharedState.loopCount++;

      sharedState.lastProgressMs = pointA;
      sharedState.lastSyncTime = now;

      await executeSeek(pointA);
      console.log(`[Loop Active] #${sharedState.loopCount} -> Seek to ${pointA}ms`);
    }
  }
}, 25);

// Periodic background device & playback sync with 204 Idle State Handling
setInterval(async () => {
  if (!sharedState.accessToken) return;
  if (Date.now() < sharedState.seekLockoutUntil) return;

  try {
    const res = await spotifyApiRequest('GET', '/v1/me/player', sharedState.accessToken);
    if (res.status === 200 && res.data && res.data.item) {
      const isTrackChanged = sharedState.currentTrackName && sharedState.currentTrackName !== res.data.item.name;
      const isExternalPause = sharedState.isPlaying && !res.data.is_playing;
      if ((isTrackChanged || isExternalPause) && sharedState.isLoopActive) {
        sharedState.isLoopActive = false;
        console.log('[Spotify App Sync] External change detected -> Paused looping (A/B preserved)');
      }

      sharedState.isIdle = false;
      sharedState.durationMs = res.data.item.duration_ms;
      sharedState.isPlaying = res.data.is_playing;
      sharedState.currentTrackName = res.data.item.name;
      sharedState.currentArtistName = res.data.item.artists ? res.data.item.artists.map(a => a.name).join(', ') : '';
      if (res.data.item.album && res.data.item.album.images && res.data.item.album.images.length > 0) {
        sharedState.albumArtUrl = res.data.item.album.images[0].url;
      }
      if (res.data.device) {
        sharedState.activeDeviceId = res.data.device.id;
        sharedState.activeDeviceName = res.data.device.name;
      }
      if (Date.now() > sharedState.seekLockoutUntil) {
        sharedState.lastProgressMs = res.data.progress_ms;
        sharedState.lastSyncTime = Date.now();
      }
    } else if (res.status === 204) {
      sharedState.isIdle = true;
      sharedState.isPlaying = false;
      sharedState.isLoopActive = false;
    }
  } catch (_) {}
}, 2500);

const server = http.createServer((req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = ['http://127.0.0.1:8888', 'http://localhost:8888'];
  if (allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  } else {
    res.setHeader('Access-Control-Allow-Origin', 'http://127.0.0.1:8888');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // API Endpoint: Get/Set Config (Client ID)
  if (req.url === '/api/config' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      clientId: sharedState.clientId || process.env.SPOTIFY_CLIENT_ID || null
    }));
    return;
  }

  if (req.url === '/api/config' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        if (payload.clientId) {
          sharedState.clientId = payload.clientId.trim();
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, clientId: sharedState.clientId }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid config payload' }));
      }
    });
    return;
  }

  // API Endpoint: Get Current Session (Auto-Login on startup/refresh)
  if (req.url === '/api/session' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      isAuthenticated: !!sharedState.accessToken,
      accessToken: sharedState.accessToken,
      refreshToken: sharedState.refreshToken,
      tokenExpiresAt: sharedState.tokenExpiresAt,
      isIdle: sharedState.isIdle,
      isPlaying: sharedState.isPlaying,
      activeDeviceName: sharedState.activeDeviceName,
      seekLeadOffsetMs: sharedState.seekLeadOffsetMs,
      loopCount: sharedState.loopCount
    }));
    return;
  }

  // API Endpoint: Sync Loop State from UI
  if (req.url === '/api/sync-state' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        let tokensUpdated = false;

        if (payload.accessToken && payload.accessToken !== sharedState.accessToken) {
          sharedState.accessToken = payload.accessToken;
          tokensUpdated = true;
        }
        if (payload.refreshToken && payload.refreshToken !== sharedState.refreshToken) {
          sharedState.refreshToken = payload.refreshToken;
          tokensUpdated = true;
        }
        if (payload.tokenExpiresAt) sharedState.tokenExpiresAt = payload.tokenExpiresAt;
        if (payload.pointA !== undefined) sharedState.pointA = payload.pointA;
        if (payload.pointB !== undefined) sharedState.pointB = payload.pointB;
        if (payload.durationMs !== undefined) sharedState.durationMs = payload.durationMs;
        if (payload.isLoopActive !== undefined) sharedState.isLoopActive = payload.isLoopActive;
        if (payload.seekLeadOffsetMs !== undefined) sharedState.seekLeadOffsetMs = payload.seekLeadOffsetMs;
        if (payload.isPlaying !== undefined) sharedState.isPlaying = payload.isPlaying;
        if (payload.activeDeviceId) sharedState.activeDeviceId = payload.activeDeviceId;
        if (payload.lastProgressMs !== undefined && Date.now() > sharedState.seekLockoutUntil) {
          sharedState.lastProgressMs = payload.lastProgressMs;
          sharedState.lastSyncTime = Date.now();
        }

        if (tokensUpdated) {
          saveSessionToFile();
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          success: true, 
          loopCount: sharedState.loopCount,
          activeDevice: sharedState.activeDeviceName,
          isIdle: sharedState.isIdle
        }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid payload' }));
      }
    });
    return;
  }

  // API Endpoint: Manual Seek Trigger
  if (req.url === '/api/seek' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const payload = JSON.parse(body);
        const ms = payload.positionMs;
        if (ms !== undefined) {
          sharedState.lastProgressMs = ms;
          sharedState.lastSyncTime = Date.now();
          sharedState.seekLockoutUntil = Date.now() + 1200;
          await executeSeek(ms);
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // API Endpoint: Disconnect & Clear Session
  if (req.url === '/api/logout' && req.method === 'POST') {
    sharedState.accessToken = null;
    sharedState.refreshToken = null;
    sharedState.tokenExpiresAt = 0;
    sharedState.isLoopActive = false;
    clearSessionFile();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  // Static asset serving (Logo / Favicon)
  if (req.url === '/assets/logo.jpg' || req.url === '/assets/logo.png' || req.url === '/favicon.ico') {
    const logoFile = path.join(__dirname, 'assets', 'logo.jpg');
    fs.readFile(logoFile, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'image/jpeg' });
      res.end(data);
    });
    return;
  }

  // Default: Serve instant_looper.html
  fs.readFile(HTML_FILE, (err, data) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Error loading app');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(data);
  });
});

// Load session immediately upon startup
loadSessionFromFile();

server.listen(PORT, HOST, () => {
  const url = `http://${HOST}:${PORT}/`;
  console.log(`\n========================================`);
  console.log(` 🔁 SpotiLoop Pro Live at ${url}`);
  console.log(` 💾 Session persistence active (.spotify_session.json)`);
  console.log(` 🎧 204 Idle handling ready`);
  console.log(`========================================\n`);
});
