/* =====================================================================
   WiFitPro · Anmeldung, Rollen und zentraler Speicher (Supabase)
   - Login / Registrierung / Passwort vergessen
   - Rollen: admin (alles) und user (Fittings und Reports, keine Teile/Räder ändern)
   - neue Konten warten auf Freischaltung durch einen Admin
   - stellt der App denselben Speicher bereit wie früher in Claude (window.claude.use("db"))
   ===================================================================== */
(function () {
  "use strict";
  const CFG = window.WF_CONFIG || {};
  const sb = window.supabase.createClient(CFG.supabaseUrl, CFG.supabaseKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  const WF = window.WF = { sb, user: null, profile: null, isAdmin: false };
  let resolveReady; const READY = new Promise(r => (resolveReady = r));
  WF.ready = READY;

  /* ---------- Speicher-Adapter: gleiche Schnittstelle wie bisher ---------- */
  const errCode = e => {
    if (!e) return "unbekannt";
    const m = String(e.message || "");
    if (e.code === "42501" || /row-level security|permission denied/i.test(m)) return "permission_denied";
    if (/fetch|network|Failed to fetch|NetworkError/i.test(m)) return "unavailable";
    return e.code || "unbekannt";
  };
  const DB = {
    doc(path) {
      return {
        async get() {
          const { data, error } = await sb.from("app_docs").select("data").eq("path", path).maybeSingle();
          if (error) throw { code: errCode(error), message: error.message };
          return { exists: !!data, data: () => (data ? data.data : undefined) };
        },
        async set(value) {
          const { error } = await sb.from("app_docs")
            .upsert({ path, data: value, updated_at: new Date().toISOString(), updated_by: WF.user ? WF.user.id : null });
          if (error) throw { code: errCode(error), message: error.message };
        }
      };
    }
  };
  const USER = {
    isOwner: () => WF.isAdmin, canEdit: () => WF.isAdmin,
    can: async k => (k === "data.write" ? WF.isAdmin : null)
  };
  window.claude = {
    use: async name => {
      if (name === "db") { await READY; return DB; }
      if (name === "user") { await READY; return USER; }
      return null;   // Download läuft über den normalen Browser-Download
    }
  };

  /* ---------- Oberfläche: Anmeldung ---------- */
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  let mode = "loading";   // loading | login | register | forgot | reset | pending
  let msg = { text: "", ok: false };

  function shell() {
    let el = document.getElementById("authScr");
    if (!el) {
      el = document.createElement("div"); el.id = "authScr"; el.setAttribute("role", "dialog"); el.setAttribute("aria-modal", "true");
      el.innerHTML = '<div class="startCard"><div class="authIn" id="authIn"></div></div>';
      document.body.appendChild(el);
    }
    el.hidden = false; return document.getElementById("authIn");
  }
  function hide() { const el = document.getElementById("authScr"); if (el) el.hidden = true; }
  const say = (text, ok = false) => { msg = { text, ok }; draw(); };

  function draw() {
    const box = shell();
    const kept = {};   // eingegebene E-Mail / Name beim Neuzeichnen behalten
    ["aMail", "aName"].forEach(id => { const el = box.querySelector("#" + id); if (el) kept[id] = el.value; });
    setTimeout(() => Object.entries(kept).forEach(([id, v]) => { const el = box.querySelector("#" + id); if (el && !el.value) el.value = v; }), 0);
    const m = msg.text ? `<p class="authMsg${msg.ok ? " ok" : ""}" role="status">${esc(msg.text)}</p>` : "";
    const head = `<h2>WiFit</h2>`;
    if (mode === "loading") { box.innerHTML = head + '<p class="authSub">Lädt …</p>'; return; }
    if (mode === "pending") {
      box.innerHTML = head + `<p class="authSub">Hallo ${esc(WF.profile && WF.profile.full_name || WF.user && WF.user.email)},<br>dein Zugang ist angelegt und wartet auf die Freischaltung durch den Admin.</p>${m}
        <div class="authBtns"><button class="startBtn pro" id="aCheck" type="button">Erneut prüfen</button>
        <button class="authLink" id="aOut" type="button">Abmelden</button></div>`;
      box.querySelector("#aCheck").onclick = () => afterLogin(true);
      box.querySelector("#aOut").onclick = signOut;
      return;
    }
    if (mode === "reset") {
      box.innerHTML = head + `<p class="authSub">Neues Passwort festlegen</p>
        <form class="authForm" id="aForm"><input type="password" id="aPw" placeholder="Neues Passwort (mind. 8 Zeichen)" autocomplete="new-password" required minlength="8">
        <input type="password" id="aPw2" placeholder="Passwort wiederholen" autocomplete="new-password" required minlength="8">${m}
        <button class="startBtn pro" type="submit">Passwort speichern</button></form>`;
      box.querySelector("#aForm").onsubmit = async e => {
        e.preventDefault(); const p = box.querySelector("#aPw").value, p2 = box.querySelector("#aPw2").value;
        if (p !== p2) return say("Die Passwörter stimmen nicht überein.");
        const { error } = await sb.auth.updateUser({ password: p });
        if (error) return say("Passwort konnte nicht gespeichert werden: " + error.message);
        msg = { text: "", ok: false }; afterLogin();
      };
      return;
    }
    const isReg = mode === "register", isForgot = mode === "forgot";
    box.innerHTML = head + `<p class="authSub">${isReg ? "Neues Konto registrieren" : isForgot ? "Passwort zurücksetzen" : "Bitte anmelden"}</p>
      <form class="authForm" id="aForm">
        ${isReg ? '<input type="text" id="aName" placeholder="Vor- und Nachname" autocomplete="name" required>' : ""}
        <input type="email" id="aMail" placeholder="E-Mail" autocomplete="email" required>
        ${isForgot ? "" : `<input type="password" id="aPw" placeholder="Passwort${isReg ? " (mind. 8 Zeichen)" : ""}" autocomplete="${isReg ? "new-password" : "current-password"}" required ${isReg ? 'minlength="8"' : ""}>`}
        ${isReg ? '<input type="password" id="aPw2" placeholder="Passwort wiederholen" autocomplete="new-password" required minlength="8">' : ""}
        ${m}
        <button class="startBtn pro" type="submit">${isReg ? "Registrieren" : isForgot ? "Link zum Zurücksetzen senden" : "Anmelden"}</button>
      </form>
      <div class="authLinks">
        ${mode !== "login" ? '<button class="authLink" data-m="login" type="button">Zur Anmeldung</button>' : '<button class="authLink" data-m="register" type="button">Neues Konto registrieren</button><button class="authLink" data-m="forgot" type="button">Passwort vergessen?</button>'}
      </div>`;
    box.querySelectorAll("[data-m]").forEach(b => (b.onclick = () => { mode = b.dataset.m; msg = { text: "", ok: false }; draw(); }));
    box.querySelector("#aForm").onsubmit = async e => {
      e.preventDefault();
      const mail = box.querySelector("#aMail").value.trim(), pwEl = box.querySelector("#aPw"), pw = pwEl ? pwEl.value : "";
      const btn = box.querySelector("button[type=submit]"); btn.disabled = true;
      try {
        if (isForgot) {
          const { error } = await sb.auth.resetPasswordForEmail(mail, { redirectTo: location.origin + location.pathname });
          if (error) return say("Fehler: " + error.message);
          return say("Wenn ein Konto mit dieser E-Mail existiert, ist ein Link zum Zurücksetzen unterwegs.", true);
        }
        if (isReg) {
          if (pw !== box.querySelector("#aPw2").value) return say("Die Passwörter stimmen nicht überein.");
          const name = box.querySelector("#aName").value.trim();
          const { data, error } = await sb.auth.signUp({ email: mail, password: pw, options: { data: { full_name: name }, emailRedirectTo: location.origin + location.pathname } });
          if (error) return say("Registrierung fehlgeschlagen: " + error.message);
          if (!data.session) { mode = "login"; return say("Fast geschafft: Bitte bestätige deine E-Mail-Adresse über den Link, den wir dir geschickt haben. Danach kannst du dich anmelden.", true); }
          return afterLogin();
        }
        const { error } = await sb.auth.signInWithPassword({ email: mail, password: pw });
        if (error) return say(/invalid/i.test(error.message) ? "E-Mail oder Passwort ist falsch." : /confirm/i.test(error.message) ? "Bitte bestätige zuerst deine E-Mail-Adresse." : "Anmeldung fehlgeschlagen: " + error.message);
        afterLogin();
      } finally { if (btn.isConnected) btn.disabled = false; }
    };
  }

  /* ---------- nach der Anmeldung: Profil prüfen ---------- */
  let started = false;
  async function afterLogin(manual) {
    const { data: { user } } = await sb.auth.getUser();
    if (!user) { mode = "login"; draw(); return; }
    WF.user = user;
    let { data: prof, error } = await sb.from("profiles").select("*").eq("id", user.id).maybeSingle();
    if (error) { mode = "login"; return say("Profil konnte nicht geladen werden: " + error.message); }
    WF.profile = prof || null;
    if (!prof || !prof.approved) { mode = "pending"; msg = manual ? { text: "Noch nicht freigeschaltet.", ok: false } : { text: "", ok: false }; draw(); return; }
    WF.isAdmin = prof.role === "admin";
    WF.canPro = WF.isAdmin || prof.access === "pro";   // Admins dürfen immer beides
    document.body.classList.toggle("isAdmin", WF.isAdmin);
    document.body.classList.toggle("noPro", !WF.canPro);
    if (!WF.canPro) { try { S.basic = true; applyBasic(); save(); } catch (e) {} }   // nur WiFitBasic freigegeben
    hide(); renderAccount();
    if (!started) { started = true; resolveReady(); }
  }
  async function signOut() {
    await sb.auth.signOut();
    try { sessionStorage.removeItem("wimove-pro"); } catch (e) {}
    location.reload();   // sauberer Neustart ohne Daten des vorherigen Kontos im Speicher
  }
  WF.signOut = signOut;

  /* ---------- Konto-Bereich und Benutzerverwaltung (Tab „Daten“) ---------- */
  function renderAccount() {
    const who = WF.profile ? `${WF.profile.full_name || ""} (${WF.profile.email || WF.user.email}) · ${WF.isAdmin ? "Admin" : WF.canPro ? "Nutzer · WiFitPro + Basic" : "Nutzer · nur WiFitBasic"}` : "";
    document.querySelectorAll(".wfWho").forEach(el => (el.textContent = who));
    document.querySelectorAll(".wfOut").forEach(b => (b.onclick = signOut));
    const pw = document.getElementById("acPwBtn");
    if (pw) pw.onclick = async () => {
      const a = document.getElementById("acPw").value, b = document.getElementById("acPw2").value, n = document.getElementById("acNote");
      if (a.length < 8) { n.textContent = "Mindestens 8 Zeichen."; return; }
      if (a !== b) { n.textContent = "Die Passwörter stimmen nicht überein."; return; }
      const { error } = await sb.auth.updateUser({ password: a });
      n.textContent = error ? "Fehler: " + error.message : "Passwort geändert.";
      if (!error) { document.getElementById("acPw").value = ""; document.getElementById("acPw2").value = ""; }
    };
    if (WF.isAdmin) renderUsers();
  }
  async function renderUsers() {
    const box = document.getElementById("userAdmin"); if (!box) return;
    box.innerHTML = '<p class="note">Lädt …</p>';
    const { data, error } = await sb.from("profiles").select("id,email,full_name,role,approved,access,created_at").order("created_at");
    if (error) { box.innerHTML = `<p class="warn">Benutzer konnten nicht geladen werden: ${esc(error.message)}</p>`; return; }
    const waiting = data.filter(p => !p.approved).length;
    box.innerHTML = (waiting ? `<p class="note" style="color:var(--dim);font-weight:600">${waiting} ${waiting === 1 ? "Konto wartet" : "Konten warten"} auf Freischaltung.</p>` : "") +
      `<div class="ulist">${data.map(p => `<div class="uitem${p.approved ? "" : " wait"}">
        <div class="uname"><b>${esc(p.full_name || "–")}</b><span>${esc(p.email)}</span><small>registriert ${new Date(p.created_at).toLocaleDateString("de-DE")}${p.id === WF.user.id ? " · du" : ""}</small></div>
        <select data-role="${p.id}" aria-label="Rolle"><option value="user"${p.role === "user" ? " selected" : ""}>Nutzer</option><option value="admin"${p.role === "admin" ? " selected" : ""}>Admin</option></select>
        <select data-acc="${p.id}" aria-label="Zugang"${p.role === "admin" ? ' disabled title="Admins haben immer beide Zugänge"' : ""}><option value="pro"${p.role === "admin" || p.access === "pro" ? " selected" : ""}>WiFitPro + Basic</option><option value="basic"${p.role !== "admin" && p.access !== "pro" ? " selected" : ""}>nur WiFitBasic</option></select>
        <button class="btn small${p.approved ? " ghost" : ""}" data-appr="${p.id}" data-v="${p.approved ? "0" : "1"}" type="button">${p.approved ? "Sperren" : "Freischalten"}</button>
      </div>`).join("")}</div><p class="note" id="uNote"></p>`;
    const note = t => { const n = document.getElementById("uNote"); if (n) n.textContent = t; };
    box.querySelectorAll("[data-appr]").forEach(b => (b.onclick = async () => {
      const { error } = await sb.from("profiles").update({ approved: b.dataset.v === "1" }).eq("id", b.dataset.appr);
      if (error) { await renderUsers(); note("Nicht möglich: " + error.message); } else renderUsers();
    }));
    box.querySelectorAll("[data-acc]").forEach(s => (s.onchange = async () => {
      const { error } = await sb.from("profiles").update({ access: s.value }).eq("id", s.dataset.acc);
      if (error) { await renderUsers(); note("Nicht möglich: " + error.message); } else { await renderUsers(); note("Zugang geändert – gilt beim nächsten Öffnen der App durch diese Person."); }
    }));
    box.querySelectorAll("[data-role]").forEach(s => (s.onchange = async () => {
      const { error } = await sb.from("profiles").update({ role: s.value }).eq("id", s.dataset.role);
      if (error) { await renderUsers(); note("Nicht möglich: " + error.message); } else renderUsers();
    }));
  }
  WF.renderUsers = renderUsers;

  /* ---------- Start ---------- */
  sb.auth.onAuthStateChange((ev) => {
    if (ev === "PASSWORD_RECOVERY") { mode = "reset"; msg = { text: "", ok: false }; draw(); }
  });
  function boot() {
    shell(); draw();   // zeigt sofort die Anmeldung, bis die Sitzung geprüft ist
    sb.auth.getSession().then(({ data }) => {
      if (mode === "reset") return;
      if (data && data.session) afterLogin(); else { mode = "login"; draw(); }
    });
    const rb = document.getElementById("userReload"); if (rb) rb.onclick = renderUsers;
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();
})();
