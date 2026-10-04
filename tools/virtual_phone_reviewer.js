const http = require('http');
const { execSync, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = 3095;
const WORKSPACE_DIR = '/home/annnpii/Product development annpii/BssparkingTimeMark';
const FEEDBACK_FILE = path.join(WORKSPACE_DIR, '.dsh_visual_feedback.json');
const SNAPSHOTS_DIR = path.join(WORKSPACE_DIR, '.dsh_snapshots');

if (!fs.existsSync(SNAPSHOTS_DIR)) {
  fs.mkdirSync(SNAPSHOTS_DIR, { recursive: true });
}

function getConnectedDevice() {
  try {
    const out = execSync('adb devices', { encoding: 'utf8' });
    const lines = out.split('\n').filter(l => l.includes('\tdevice'));
    if (lines.length > 0) {
      return lines[0].split('\t')[0].trim();
    }
  } catch (_) {}
  return '102682538I005259';
}

function captureScreenshot(deviceId) {
  try {
    return execSync(`adb -s ${deviceId} exec-out screencap -p`, { maxBuffer: 15 * 1024 * 1024 });
  } catch (e) {
    return null;
  }
}

function getFeedbacks() {
  if (fs.existsSync(FEEDBACK_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(FEEDBACK_FILE, 'utf8'));
    } catch (_) {}
  }
  return [];
}

function saveFeedbacks(list) {
  fs.writeFileSync(FEEDBACK_FILE, JSON.stringify(list, null, 2), 'utf8');
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const deviceId = getConnectedDevice();

  if (url.pathname === '/api/screenshot') {
    const png = captureScreenshot(deviceId);
    if (png) {
      res.writeHead(200, {
        'Content-Type': 'image/png',
        'Cache-Control': 'no-store, must-revalidate',
      });
      res.end(png);
    } else {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Gagal mengambil screenshot dari ADB' }));
    }
    return;
  }

  if (url.pathname === '/api/feedback' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(getFeedbacks()));
    return;
  }

  if (url.pathname === '/api/feedback' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const feedbacks = getFeedbacks();
        const id = 'fb_' + Date.now();
        const newEntry = {
          id,
          timestamp: new Date().toISOString(),
          deviceId,
          pins: data.pins || [],
          generalNote: data.generalNote || '',
          status: 'pending',
        };
        feedbacks.unshift(newEntry);
        saveFeedbacks(feedbacks);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, entry: newEntry }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  if (url.pathname === '/api/clear-feedback' && req.method === 'POST') {
    saveFeedbacks([]);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  // HTML Reviewer GUI
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BSS Virtual Phone Visual Reviewer</title>
  <style>
    :root {
      --primary: #1E489C;
      --primary-hover: #163675;
      --accent: #F59E0B;
      --bg: #0F172A;
      --panel: #1E293B;
      --card: #334155;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --danger: #EF4444;
      --success: #10B981;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: var(--bg); color: var(--text); display: flex; height: 100vh; overflow: hidden; }
    
    /* Left Sidebar: Controls & Annotations */
    .sidebar {
      width: 420px;
      background: var(--panel);
      border-right: 1px solid rgba(255,255,255,0.1);
      display: flex;
      flex-direction: column;
      height: 100%;
    }
    .header {
      padding: 16px 20px;
      background: var(--primary);
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .header h1 { font-size: 16px; font-weight: 800; letter-spacing: 0.5px; }
    .device-badge { background: rgba(255,255,255,0.2); padding: 4px 8px; border-radius: 6px; font-size: 11px; font-weight: bold; }
    
    .toolbar {
      padding: 12px 16px;
      background: rgba(0,0,0,0.2);
      display: flex;
      gap: 8px;
      border-bottom: 1px solid rgba(255,255,255,0.05);
    }
    button {
      background: var(--primary);
      color: white;
      border: none;
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }
    button:hover { background: var(--primary-hover); transform: translateY(-1px); }
    button.secondary { background: var(--card); }
    button.secondary:hover { background: #475569; }
    button.danger { background: var(--danger); }
    button.success { background: var(--success); }
    
    .content-scroll { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 14px; }
    
    .instruction-card {
      background: rgba(30, 72, 156, 0.15);
      border: 1px solid rgba(30, 72, 156, 0.4);
      border-radius: 10px;
      padding: 12px 14px;
      font-size: 12px;
      line-height: 1.4;
    }
    .instruction-card b { color: var(--accent); }
    
    .pin-list-title { font-size: 13px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }
    
    .pin-item {
      background: var(--card);
      border-radius: 8px;
      padding: 10px 12px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      border-left: 4px solid var(--accent);
      position: relative;
    }
    .pin-header { display: flex; justify-content: space-between; align-items: center; }
    .pin-tag { background: var(--accent); color: black; font-weight: 900; font-size: 11px; padding: 2px 6px; border-radius: 4px; }
    .pin-coord { font-size: 10px; color: var(--text-muted); font-family: monospace; }
    .pin-comment { font-size: 12.5px; line-height: 1.3; }
    .pin-delete { background: transparent; color: #EF4444; padding: 2px 6px; font-size: 11px; border-radius: 4px; }
    .pin-delete:hover { background: rgba(239, 68, 68, 0.15); }
    
    .general-input {
      width: 100%;
      background: #0F172A;
      border: 1px solid var(--card);
      border-radius: 8px;
      padding: 10px;
      color: white;
      font-size: 12px;
      resize: vertical;
      min-height: 60px;
    }
    .general-input:focus { outline: none; border-color: var(--primary); }
    
    .submit-section {
      padding: 16px;
      background: rgba(0,0,0,0.3);
      border-top: 1px solid rgba(255,255,255,0.1);
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    
    /* Right Viewport: Phone Frame & Canvas */
    .viewport {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      background: radial-gradient(circle at center, #1E293B 0%, #0F172A 100%);
      position: relative;
      overflow: auto;
    }
    
    .phone-container {
      position: relative;
      box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.8), 0 0 0 12px #1E293B, 0 0 0 14px rgba(255,255,255,0.1);
      border-radius: 36px;
      overflow: hidden;
      background: #000;
      cursor: crosshair;
      user-select: none;
      max-height: 90vh;
      display: inline-block;
    }
    
    .screen-img {
      display: block;
      max-height: 86vh;
      width: auto;
      object-fit: contain;
    }
    
    /* Pin Marker Overlay */
    .pin-marker {
      position: absolute;
      transform: translate(-50%, -50%);
      width: 28px;
      height: 28px;
      background: var(--danger);
      color: white;
      border: 2px solid white;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 900;
      font-size: 12px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.5);
      animation: pulse 1.5s infinite;
      pointer-events: none;
    }
    
    @keyframes pulse {
      0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7); }
      70% { box-shadow: 0 0 0 10px rgba(239, 68, 68, 0); }
      100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
    }
    
    /* Modal Dialog for Comment Input */
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.7);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 999;
    }
    .modal-box {
      background: var(--panel);
      border: 1px solid rgba(255,255,255,0.15);
      border-radius: 14px;
      padding: 20px;
      width: 440px;
      box-shadow: 0 20px 40px rgba(0,0,0,0.6);
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .modal-box h3 { font-size: 15px; color: var(--text); }
    .quick-tags { display: flex; flex-wrap: wrap; gap: 6px; }
    .quick-tag {
      background: var(--card);
      font-size: 11px;
      padding: 4px 8px;
      border-radius: 6px;
      cursor: pointer;
      border: 1px solid rgba(255,255,255,0.1);
    }
    .quick-tag:hover { background: var(--primary); }
    
    .modal-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 6px; }
  </style>
</head>
<body>

  <!-- LEFT CONTROLS -->
  <div class="sidebar">
    <div class="header">
      <div>
        <h1>Virtual Phone Visual Reviewer</h1>
        <div style="font-size: 11px; color: #CBD5E1; margin-top: 2px;">BSS Parking Timemark</div>
      </div>
      <div class="device-badge">${deviceId}</div>
    </div>

    <div class="toolbar">
      <button onclick="refreshScreen()">🔄 Refresh Layar</button>
      <button class="secondary" onclick="clearPins()">🗑️ Reset Pin</button>
    </div>

    <div class="content-scroll">
      <div class="instruction-card">
        🎯 <b>Cara Tandai UI:</b><br>
        1. Klik di bagian layar HP sebelah kanan.<br>
        2. Tulis komentar/perubahan yang diinginkan.<br>
        3. Klik <b>"Kirim Feedback ke AI"</b> agar AI langsung membaca & memodifikasi kode!
      </div>

      <div class="pin-list-title">Daftar Penandaan UI (<span id="pinCount">0</span>)</div>
      <div id="pinList" style="display: flex; flex-direction: column; gap: 8px;">
        <div style="color: var(--text-muted); font-size: 12px; text-align: center; padding: 20px;">
          Belum ada pin. Klik pada layar HP di samping untuk mulai menandai.
        </div>
      </div>

      <div class="pin-list-title">Catatan Tambahan (Opsional)</div>
      <textarea id="generalNote" class="general-input" placeholder="Instruksi umum atau catatan menyeluruh..."></textarea>
    </div>

    <div class="submit-section">
      <button class="success" style="width: 100%; justify-content: center; padding: 12px; font-size: 14px;" onclick="submitFeedback()">
        🚀 Kirim Feedback ke AI Agent
      </button>
    </div>
  </div>

  <!-- RIGHT PHONE VIEWPORT -->
  <div class="viewport">
    <div class="phone-container" id="phoneBox" onclick="handleScreenClick(event)">
      <img id="screenImg" class="screen-img" src="/api/screenshot" alt="Live Screen" onload="onImgLoaded()" />
      <div id="markersLayer"></div>
    </div>
  </div>

  <!-- MODAL COMMENT INPUT -->
  <div class="modal-overlay" id="commentModal">
    <div class="modal-box">
      <h3>Tandai & Tulis Perubahan UI</h3>
      <div style="font-size: 11.5px; color: var(--text-muted);">
        Posisi Klik: <span id="posText" style="font-family: monospace; color: var(--accent);"></span>
      </div>

      <div class="quick-tags">
        <span class="quick-tag" onclick="addQuickText('Ganti teks ini jadi: ')">✏️ Ganti Teks</span>
        <span class="quick-tag" onclick="addQuickText('Ubah warna ini jadi #')">🎨 Ubah Warna</span>
        <span class="quick-tag" onclick="addQuickText('Perbesar ukuran font')">🔤 Font Size</span>
        <span class="quick-tag" onclick="addQuickText('Geser posisi ke ')">📐 Geser Posisi</span>
        <span class="quick-tag" onclick="addQuickText('Hapus elemen ini')">❌ Hapus Elemen</span>
      </div>

      <textarea id="pinCommentInput" class="general-input" rows="3" placeholder="Tuliskan apa yang ingin kamu ubah di bagian ini..."></textarea>

      <div class="modal-actions">
        <button class="secondary" onclick="closeModal()">Batal</button>
        <button onclick="savePin()">Simpan Pin</button>
      </div>
    </div>
  </div>

  <script>
    let pins = [];
    let pendingClick = null;

    function refreshScreen() {
      const img = document.getElementById('screenImg');
      img.src = '/api/screenshot?t=' + Date.now();
    }

    function onImgLoaded() {
      renderMarkers();
    }

    function handleScreenClick(e) {
      const img = document.getElementById('screenImg');
      const rect = img.getBoundingClientRect();

      const clickX = e.clientX - rect.left;
      const clickY = e.clientY - rect.top;

      if (clickX < 0 || clickX > rect.width || clickY < 0 || clickY > rect.height) return;

      const pctX = ((clickX / rect.width) * 100).toFixed(1);
      const pctY = ((clickY / rect.height) * 100).toFixed(1);

      pendingClick = { pctX: parseFloat(pctX), pctY: parseFloat(pctY) };

      document.getElementById('posText').innerText = 'X: ' + pctX + '%, Y: ' + pctY + '%';
      document.getElementById('pinCommentInput').value = '';
      document.getElementById('commentModal').style.display = 'flex';
      document.getElementById('pinCommentInput').focus();
    }

    function addQuickText(txt) {
      const input = document.getElementById('pinCommentInput');
      input.value = txt;
      input.focus();
    }

    function closeModal() {
      document.getElementById('commentModal').style.display = 'none';
      pendingClick = null;
    }

    function savePin() {
      const comment = document.getElementById('pinCommentInput').value.trim();
      if (!comment || !pendingClick) return;

      pins.push({
        id: pins.length + 1,
        x: pendingClick.pctX,
        y: pendingClick.pctY,
        comment: comment
      });

      closeModal();
      renderPinsList();
      renderMarkers();
    }

    function deletePin(index) {
      pins.splice(index, 1);
      pins.forEach((p, idx) => p.id = idx + 1);
      renderPinsList();
      renderMarkers();
    }

    function clearPins() {
      pins = [];
      renderPinsList();
      renderMarkers();
    }

    function renderPinsList() {
      document.getElementById('pinCount').innerText = pins.length;
      const list = document.getElementById('pinList');

      if (pins.length === 0) {
        list.innerHTML = '<div style="color: var(--text-muted); font-size: 12px; text-align: center; padding: 20px;">Belum ada pin. Klik pada layar HP di samping untuk mulai menandai.</div>';
        return;
      }

      list.innerHTML = pins.map((p, idx) => \`
        <div class="pin-item">
          <div class="pin-header">
            <span class="pin-tag">PIN #\${p.id}</span>
            <span class="pin-coord">\${p.x}% , \${p.y}%</span>
            <button class="pin-delete" onclick="deletePin(\${idx})">Hapus</button>
          </div>
          <div class="pin-comment">\${p.comment}</div>
        </div>
      \`).join('');
    }

    function renderMarkers() {
      const container = document.getElementById('markersLayer');
      container.innerHTML = pins.map(p => \`
        <div class="pin-marker" style="left: \${p.x}%; top: \${p.y}%;">\${p.id}</div>
      \`).join('');
    }

    async function submitFeedback() {
      if (pins.length === 0 && !document.getElementById('generalNote').value.trim()) {
        alert('Tandai minimal 1 bagian pada layar atau isi catatan.');
        return;
      }

      const payload = {
        pins: pins,
        generalNote: document.getElementById('generalNote').value.trim()
      };

      try {
        const res = await fetch('/api/feedback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        if (res.ok) {
          alert('✅ Feedback visual berhasil dikirim ke AI! AI Agent sekarang dapat langsung membaca pin & caption kamu.');
        } else {
          alert('Gagal mengirim feedback.');
        }
      } catch (err) {
        alert('Error: ' + err.message);
      }
    }
  </script>
</body>
</html>`);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Virtual Phone Reviewer] Server running on http://127.0.0.1:${PORT}`);
});
