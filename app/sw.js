/* Offline-Unterstützung: App-Dateien zwischenspeichern.
   Seiten und Skripte: zuerst aus dem Netz (immer aktuell), offline aus dem Zwischenspeicher.
   Bilder: aus dem Zwischenspeicher. Anfragen an Supabase werden nie zwischengespeichert. */
const CACHE = "wifitpro-v5";   // bei geänderten Bildern hochzählen
const CORE = ["./", "index.html", "auth.js", "config.js", "vendor/supabase.js", "manifest.webmanifest",
  "brand/start.jpg", "brand/cover_plus.jpg", "brand/cover_advanced.jpg", "brand/cover_professional.jpg", "brand/cover_basic.jpg",
  "brand/back.jpg", "brand/back_basic.jpg", "brand/footer.png", "brand/footer_basic.png", "icons/icon-192.png", "icons/icon-512.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const req = e.request; if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname.endsWith("supabase.co")) return;
  const isImg = /\.(jpg|png|webp|svg)$/i.test(url.pathname);
  if (isImg) { e.respondWith(caches.match(req).then(r => r || fetch(req).then(res => { const c = res.clone(); caches.open(CACHE).then(k => k.put(req, c)); return res; }))); return; }
  e.respondWith(fetch(req).then(res => { if (res.ok && (url.origin === location.origin || /cdnjs|fonts\.g/.test(url.hostname))) { const c = res.clone(); caches.open(CACHE).then(k => k.put(req, c)); } return res; })
    .catch(() => caches.match(req).then(r => r || caches.match("index.html"))));
});
