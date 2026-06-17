<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Local IoT Hub</title>
<style>
  :root {
    --bg: #0e1116;
    --panel: #161b22;
    --panel-2: #1c232d;
    --line: #2a3340;
    --ink: #e6edf3;
    --ink-dim: #8b97a7;
    --accent: #6fe3c4;       /* signal teal */
    --accent-2: #ffb454;     /* amber for actuators */
    --danger: #ff6b6b;
    --ok: #6fe3c4;
    --mono: "JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace;
    --sans: "Inter", system-ui, -apple-system, sans-serif;
    --r: 10px;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font-family: var(--sans); font-size: 14px; line-height: 1.5;
  }
  a { color: var(--accent); }
  header {
    padding: 18px 24px; border-bottom: 1px solid var(--line);
    display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap;
    background: linear-gradient(180deg, #11161d, var(--bg));
  }
  header h1 {
    margin: 0; font-size: 18px; letter-spacing: .14em; text-transform: uppercase;
    font-weight: 600;
  }
  header h1 .dot { color: var(--accent); }
  header .meta { font-family: var(--mono); font-size: 12px; color: var(--ink-dim); }
  #health { margin-left: auto; font-family: var(--mono); font-size: 12px; color: var(--ink-dim); }
  #health b { color: var(--ok); }

  .wrap { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; padding: 20px 24px; align-items: start; }
  .card { background: var(--panel); border: 1px solid var(--line); border-radius: var(--r); overflow: hidden; }
  .card > .head {
    padding: 12px 16px; border-bottom: 1px solid var(--line);
    display: flex; align-items: center; gap: 10px;
    background: var(--panel-2);
  }
  .card > .head .kind {
    font-family: var(--mono); font-size: 10px; letter-spacing: .12em;
    text-transform: uppercase; color: var(--bg); background: var(--accent);
    padding: 3px 7px; border-radius: 4px; font-weight: 700;
  }
  .card.actuator > .head .kind { background: var(--accent-2); }
  .card > .head h2 { margin: 0; font-size: 14px; font-weight: 600; }
  .card .body { padding: 14px 16px; }

  fieldset { border: 1px dashed var(--line); border-radius: 8px; margin: 0 0 14px; padding: 12px; }
  legend { font-family: var(--mono); font-size: 11px; color: var(--ink-dim); padding: 0 6px; text-transform: uppercase; letter-spacing: .08em; }

  label { display: block; font-size: 11px; color: var(--ink-dim); margin: 8px 0 3px; }
  input, select {
    width: 100%; background: var(--bg); color: var(--ink);
    border: 1px solid var(--line); border-radius: 6px; padding: 7px 9px;
    font-family: var(--mono); font-size: 13px;
  }
  input:focus, select:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
  .row { display: flex; gap: 8px; }
  .row > * { flex: 1; }

  button {
    background: var(--panel-2); color: var(--ink); border: 1px solid var(--line);
    border-radius: 6px; padding: 8px 12px; cursor: pointer; font-family: var(--sans);
    font-size: 13px; font-weight: 500; transition: border-color .12s, background .12s;
  }
  button:hover { border-color: var(--accent); }
  button:active { transform: translateY(1px); }
  button.primary { background: var(--accent); color: #06231c; border-color: var(--accent); font-weight: 600; }
  button.warn { border-color: var(--danger); color: var(--danger); }
  .btnrow { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
  .btnrow button { flex: 1; min-width: 70px; }

  .devlist { list-style: none; margin: 0 0 12px; padding: 0; }
  .devlist li {
    display: flex; align-items: center; gap: 8px; padding: 7px 10px;
    border: 1px solid var(--line); border-radius: 6px; margin-bottom: 6px;
    font-family: var(--mono); font-size: 12px; background: var(--bg);
  }
  .devlist li.sel { border-color: var(--accent); }
  .devlist li .ip { color: var(--accent); }
  .devlist li button { padding: 3px 8px; font-size: 11px; margin-left: auto; }
  .devlist li .pick { color: var(--ink-dim); }
  .empty { color: var(--ink-dim); font-style: italic; font-size: 12px; }

  /* PTZ pad */
  .ptz { display: grid; grid-template-columns: repeat(3, 56px); grid-template-rows: repeat(3, 56px); gap: 6px; justify-content: center; margin: 12px auto; }
  .ptz button { font-size: 18px; padding: 0; }
  .ptz .c { background: transparent; border-style: dashed; }
  .ptz .up { grid-area: 1/2; } .ptz .left { grid-area: 2/1; }
  .ptz .stop { grid-area: 2/2; } .ptz .right { grid-area: 2/3; } .ptz .down { grid-area: 3/2; }

  video { width: 100%; border-radius: 8px; background: #000; aspect-ratio: 16/9; }
  .vidmeta { display: flex; justify-content: space-between; font-family: var(--mono); font-size: 11px; color: var(--ink-dim); margin-top: 6px; }
  .vidmeta .live::before { content: "●"; color: var(--danger); margin-right: 5px; }
  .vidmeta .live.on::before { color: var(--ok); }

  .kv { display: grid; grid-template-columns: 1fr auto; gap: 4px 12px; font-family: var(--mono); font-size: 12px; margin: 4px 0 12px; }
  .kv .k { color: var(--ink-dim); }
  .kv .v { text-align: right; }

  /* console */
  #console { grid-column: 1 / -1; background: #0a0d12; border: 1px solid var(--line); border-radius: var(--r); }
  #console .head { padding: 10px 16px; border-bottom: 1px solid var(--line); font-family: var(--mono); font-size: 11px; letter-spacing: .1em; text-transform: uppercase; color: var(--ink-dim); display:flex; }
  #console .head button { margin-left:auto; padding: 2px 8px; font-size: 11px; }
  #log { max-height: 220px; overflow: auto; padding: 12px 16px; font-family: var(--mono); font-size: 12px; }
  #log .line { white-space: pre-wrap; word-break: break-all; padding: 1px 0; }
  #log .t { color: var(--ink-dim); }
  #log .ok { color: var(--ok); }
  #log .err { color: var(--danger); }
  #log .req { color: var(--accent-2); }
  .swatch { width: 20px; height: 20px; border-radius: 4px; border: 1px solid var(--line); display:inline-block; vertical-align: middle; margin-left: 8px; }
</style>
</head>
<body>
<header>
  <h1>Local IoT <span class="dot">●</span> Hub</h1>
  <span class="meta">LAN-only · FastAPI · WebRTC</span>
  <span id="health">checking…</span>
</header>

<div class="wrap">

  <!-- ============ CCTV ============ -->
  <section class="card" id="card-cctv">
    <div class="head"><span class="kind">CCTV</span><h2>Cameras (ONVIF + WebRTC)</h2></div>
    <div class="body">
      <ul class="devlist" id="cctv-list"><li class="empty">No cameras registered.</li></ul>
      <fieldset>
        <legend>Register camera</legend>
        <div class="row">
          <div><label>IP</label><input id="cctv-ip" placeholder="192.168.1.12" /></div>
          <div><label>Name</label><input id="cctv-name" placeholder="Living room" /></div>
        </div>
        <div class="row">
          <div><label>User</label><input id="cctv-user" placeholder="circulus" /></div>
          <div><label>Password</label><input id="cctv-pass" type="password" /></div>
        </div>
        <div class="row">
          <div><label>RTSP port</label><input id="cctv-rtsp" value="554" /></div>
          <div><label>ONVIF port</label><input id="cctv-onvif" value="2020" /></div>
          <div><label>Stream</label><input id="cctv-stream" value="stream1" /></div>
        </div>
        <div class="btnrow"><button class="primary" onclick="cctvRegister()">Register</button></div>
      </fieldset>

      <video id="cctv-video" autoplay playsinline muted></video>
      <div class="vidmeta">
        <span id="cctv-live" class="live">offline</span>
        <span id="cctv-target">no camera selected</span>
      </div>
      <div class="btnrow">
        <button class="primary" id="cctv-connect" onclick="cctvConnect()" disabled>Start stream</button>
        <button onclick="cctvDisconnect()">Stop</button>
      </div>

      <div class="ptz">
        <button class="up"    onmousedown="ptz(0,0.5)">↑</button>
        <button class="left"  onmousedown="ptz(-0.5,0)">←</button>
        <button class="stop c" onmousedown="ptz(0,0)">■</button>
        <button class="right" onmousedown="ptz(0.5,0)">→</button>
        <button class="down"  onmousedown="ptz(0,-0.5)">↓</button>
      </div>
      <p class="empty" style="text-align:center">PTZ uses the WebRTC data channel when streaming, otherwise REST. Arrow keys work too.</p>
    </div>
  </section>

  <!-- ============ LED ============ -->
  <section class="card actuator" id="card-led">
    <div class="head"><span class="kind">LED</span><h2>Tapo Bulbs</h2></div>
    <div class="body">
      <ul class="devlist" id="led-list"><li class="empty">No bulbs registered.</li></ul>
      <fieldset>
        <legend>Register bulb</legend>
        <div class="row">
          <div><label>IP</label><input id="led-ip" placeholder="192.168.1.109" /></div>
          <div><label>Name</label><input id="led-name" placeholder="Desk lamp" /></div>
        </div>
        <div class="row">
          <div><label>Tapo email</label><input id="led-email" /></div>
          <div><label>Tapo password</label><input id="led-pass" type="password" /></div>
        </div>
        <div class="btnrow"><button class="primary" onclick="ledRegister()">Register</button></div>
      </fieldset>

      <div data-target="led">
        <div class="btnrow">
          <button class="primary" onclick="ledPower(true)">On</button>
          <button onclick="ledPower(false)">Off</button>
        </div>
        <label>Brightness <span id="led-br-val">50</span>%</label>
        <input type="range" min="1" max="100" value="50" id="led-br" oninput="document.getElementById('led-br-val').textContent=this.value" onchange="ledBrightness(this.value)" />
        <div class="row">
          <div><label>Hue (0–360)</label><input id="led-hue" value="120" /></div>
          <div><label>Saturation (0–100)</label><input id="led-sat" value="80" /></div>
        </div>
        <div class="btnrow">
          <button onclick="ledColor()">Set color <span class="swatch" id="led-swatch"></span></button>
        </div>
        <label>Color temp <span id="led-ct-val">2700</span>K (warm→cool)</label>
        <input type="range" min="2500" max="6500" step="100" value="2700" id="led-ct" oninput="document.getElementById('led-ct-val').textContent=this.value" onchange="ledColorTemp(this.value)" />
      </div>
    </div>
  </section>

  <!-- ============ AIR ============ -->
  <section class="card actuator" id="card-air">
    <div class="head"><span class="kind">AIR</span><h2>Xiaomi Air Purifier</h2></div>
    <div class="body">
      <ul class="devlist" id="air-list"><li class="empty">No purifiers registered.</li></ul>
      <fieldset>
        <legend>Register purifier</legend>
        <div class="row">
          <div><label>IP</label><input id="air-ip" placeholder="192.168.1.210" /></div>
          <div><label>Name</label><input id="air-name" placeholder="Bedroom" /></div>
        </div>
        <label>Token (32 chars)</label><input id="air-token" />
        <div class="btnrow"><button class="primary" onclick="airRegister()">Register</button></div>
      </fieldset>

      <div data-target="air">
        <div class="kv" id="air-status"><span class="empty" style="grid-column:1/-1">Select a purifier and refresh.</span></div>
        <div class="btnrow"><button onclick="airStatus()">Refresh status</button></div>
        <div class="btnrow">
          <button class="primary" onclick="airPower(true)">On</button>
          <button onclick="airPower(false)">Off</button>
        </div>
        <label>Mode</label>
        <select id="air-mode" onchange="airMode(this.value)">
          <option>Auto</option><option>Silent</option><option>Favorite</option><option>Fan</option>
        </select>
        <label>Favorite level <span id="air-lvl-val">7</span> (1–14)</label>
        <input type="range" min="1" max="14" value="7" id="air-lvl" oninput="document.getElementById('air-lvl-val').textContent=this.value" onchange="airFavorite(this.value)" />
        <label>Display LED</label>
        <select id="air-led" onchange="airLed(this.value)">
          <option>Bright</option><option>Dim</option><option>Off</option>
        </select>
        <div class="btnrow">
          <button onclick="airToggle('anion',true)">Anion on</button>
          <button onclick="airToggle('anion',false)">Anion off</button>
          <button onclick="airToggle('buzzer',true)">Buzzer on</button>
          <button onclick="airToggle('buzzer',false)">Buzzer off</button>
        </div>
        <div class="btnrow">
          <button onclick="airToggle('child_lock',true)">Lock on</button>
          <button onclick="airToggle('child_lock',false)">Lock off</button>
        </div>
      </div>
    </div>
  </section>

  <!-- ============ CONSOLE ============ -->
  <section id="console">
    <div class="head">Request log <button onclick="document.getElementById('log').innerHTML=''">clear</button></div>
    <div id="log"></div>
  </section>
</div>

<script>
const sel = { led: null, air: null, cctv: null };
let pc = null, ptzChannel = null, currentStreamIp = null;

// ---------- logging + fetch ----------
function log(msg, cls="") {
  const el = document.getElementById("log");
  const t = new Date().toLocaleTimeString();
  const line = document.createElement("div");
  line.className = "line";
  line.innerHTML = `<span class="t">${t}</span> <span class="${cls}">${msg}</span>`;
  el.prepend(line);
}
async function api(method, path, body) {
  log(`${method} ${path}`, "req");
  try {
    const opt = { method, headers: { "Content-Type": "application/json" } };
    if (body !== undefined) opt.body = JSON.stringify(body);
    const r = await fetch(path, opt);
    const text = await r.text();
    let data; try { data = JSON.parse(text); } catch { data = text; }
    if (!r.ok) { log(`  ↳ ${r.status} ${JSON.stringify(data)}`, "err"); throw data; }
    log(`  ↳ ${typeof data === "string" ? data : JSON.stringify(data)}`, "ok");
    return data;
  } catch (e) {
    if (e instanceof TypeError) log(`  ↳ network error: ${e.message}`, "err");
    throw e;
  }
}

// ---------- health + lists ----------
async function health() {
  try {
    const h = await fetch("/api/health").then(r => r.json());
    document.getElementById("health").innerHTML = "api <b>online</b>";
  } catch { document.getElementById("health").innerHTML = "api <b style='color:var(--danger)'>offline</b>"; }
}
function renderList(kind, items, onpick) {
  const ul = document.getElementById(`${kind}-list`);
  if (!items.length) { ul.innerHTML = `<li class="empty">None registered.</li>`; return; }
  ul.innerHTML = "";
  for (const d of items) {
    const li = document.createElement("li");
    if (sel[kind] === d.ip) li.classList.add("sel");
    li.innerHTML = `<span class="ip">${d.ip}</span><span>${d.name||""}</span>
      <span class="pick">${sel[kind]===d.ip?"● selected":"tap to select"}</span>
      <button class="warn" onclick="event.stopPropagation();delDevice('${kind}','${d.ip}')">✕</button>`;
    li.onclick = () => { sel[kind] = d.ip; onpick && onpick(d); refresh(kind); };
    ul.appendChild(li);
  }
}
async function refresh(kind) {
  const items = await api("GET", `/api/${kind}/list`);
  if (kind === "cctv") {
    renderList("cctv", items, d => {
      document.getElementById("cctv-target").textContent = `${d.ip} ${d.ptz?"":"(no PTZ)"}`;
      document.getElementById("cctv-connect").disabled = false;
    });
  } else renderList(kind, items);
}
async function delDevice(kind, ip) {
  await api("DELETE", `/api/${kind}/${ip}`);
  if (sel[kind] === ip) sel[kind] = null;
  if (kind === "cctv" && currentStreamIp === ip) cctvDisconnect();
  refresh(kind);
}
function need(kind) {
  if (!sel[kind]) { log(`select a ${kind} device first`, "err"); throw new Error("no selection"); }
  return sel[kind];
}

// ---------- LED ----------
async function ledRegister() {
  await api("POST", "/api/led/register", {
    ip: v("led-ip"), name: v("led-name"), email: v("led-email"), password: v("led-pass"),
  }); refresh("led");
}
async function ledPower(on) { await api("POST", `/api/led/${need('led')}/power`, { on }); }
async function ledBrightness(b) { await api("POST", `/api/led/${need('led')}/brightness`, { brightness: +b }); }
async function ledColor() {
  const hue = +v("led-hue"), saturation = +v("led-sat");
  document.getElementById("led-swatch").style.background = `hsl(${hue} ${saturation}% 50%)`;
  await api("POST", `/api/led/${need('led')}/color`, { hue, saturation });
}
async function ledColorTemp(t) { await api("POST", `/api/led/${need('led')}/color_temp`, { temp: +t }); }

// ---------- AIR ----------
async function airRegister() {
  await api("POST", "/api/air/register", { ip: v("air-ip"), name: v("air-name"), token: v("air-token") });
  refresh("air");
}
async function airStatus() {
  const s = await api("GET", `/api/air/${need('air')}/status`);
  const order = ["on","aqi","temperature","humidity","mode","anion","motor_speed","filter_life_remaining","filter_hours_used","child_lock","buzzer"];
  document.getElementById("air-status").innerHTML =
    order.map(k => `<span class="k">${k}</span><span class="v">${s[k]}</span>`).join("");
}
async function airPower(on) { await api("POST", `/api/air/${need('air')}/power`, { on }); }
async function airMode(mode) { await api("POST", `/api/air/${need('air')}/mode`, { mode }); }
async function airFavorite(level) { await api("POST", `/api/air/${need('air')}/favorite_level`, { level: +level }); }
async function airLed(brightness) { await api("POST", `/api/air/${need('air')}/led`, { brightness }); }
async function airToggle(what, on) { await api("POST", `/api/air/${need('air')}/${what}`, { on }); }

// ---------- CCTV PTZ ----------
async function ptz(x, y) {
  const ip = need("cctv");
  if (ptzChannel && ptzChannel.readyState === "open") {
    ptzChannel.send(JSON.stringify({ action: "move", x, y, duration: 0.4 }));
    log(`PTZ(webrtc) x=${x} y=${y}`, "req");
  } else {
    await api("POST", `/api/cctv/${ip}/move`, { x, y, duration: 0.4 });
  }
}
document.addEventListener("keydown", e => {
  if (!sel.cctv) return;
  const m = { ArrowUp:[0,.5], ArrowDown:[0,-.5], ArrowLeft:[-.5,0], ArrowRight:[.5,0] }[e.key];
  if (m) { e.preventDefault(); ptz(m[0], m[1]); }
});

// ---------- CCTV register + WebRTC ----------
async function cctvRegister() {
  await api("POST", "/api/cctv/register", {
    ip: v("cctv-ip"), name: v("cctv-name"), user: v("cctv-user"), password: v("cctv-pass"),
    rtsp_port: +v("cctv-rtsp"), onvif_port: +v("cctv-onvif"), stream: v("cctv-stream"),
  }); refresh("cctv");
}
async function cctvConnect() {
  const ip = need("cctv");
  cctvDisconnect();
  pc = new RTCPeerConnection();   // no STUN -> LAN candidates only
  pc.addTransceiver("video", { direction: "recvonly" });
  ptzChannel = pc.createDataChannel("ptz");
  ptzChannel.onopen = () => log("PTZ data channel open", "ok");
  ptzChannel.onmessage = e => log("PTZ ack " + e.data, "ok");

  pc.ontrack = e => {
    document.getElementById("cctv-video").srcObject = e.streams[0];
    document.getElementById("cctv-live").textContent = "live";
    document.getElementById("cctv-live").classList.add("on");
  };
  pc.onconnectionstatechange = () => log("pc: " + pc.connectionState);

  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  // wait for ICE gathering (local candidates only, fast on LAN)
  await new Promise(res => {
    if (pc.iceGatheringState === "complete") return res();
    const check = () => { if (pc.iceGatheringState === "complete") { pc.removeEventListener("icegatheringstatechange", check); res(); } };
    pc.addEventListener("icegatheringstatechange", check);
    setTimeout(res, 1500);
  });
  const answer = await api("POST", `/api/cctv/${ip}/webrtc`,
    { sdp: pc.localDescription.sdp, type: pc.localDescription.type });
  await pc.setRemoteDescription(answer);
  currentStreamIp = ip;
}
function cctvDisconnect() {
  if (pc) { pc.close(); pc = null; }
  ptzChannel = null; currentStreamIp = null;
  document.getElementById("cctv-video").srcObject = null;
  const live = document.getElementById("cctv-live");
  live.textContent = "offline"; live.classList.remove("on");
}

// ---------- utils + boot ----------
function v(id) { return document.getElementById(id).value.trim(); }
health();
["led","air","cctv"].forEach(refresh);
setInterval(health, 5000);
</script>
</body>
</html>
