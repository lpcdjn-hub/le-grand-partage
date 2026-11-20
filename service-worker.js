const CACHE = "grand-partage-v14";
const APP = ["/le-grand-partage/", "/le-grand-partage/index.html", "/le-grand-partage/manifest.webmanifest", "/le-grand-partage/icon.svg", "/le-grand-partage/logo.svg"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(APP)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET" || new URL(event.request.url).origin !== self.location.origin) return;
  const url = new URL(event.request.url);
  const isAppShell = event.request.mode === "navigate" || url.pathname === "/le-grand-partage/" || url.pathname === "/le-grand-partage/index.html";
  if (isAppShell) {
    event.respondWith(fetch(event.request).then(response => {
      if (response.ok) caches.open(CACHE).then(cache => cache.put(event.request, response.clone()));
      return response;
    }).catch(() => caches.match(event.request).then(cached => cached || caches.match("/le-grand-partage/index.html"))));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
    if (response.ok) { const copy = response.clone(); caches.open(CACHE).then(cache => cache.put(event.request, copy)); }
    return response;
  }).catch(() => caches.match("/le-grand-partage/index.html"))));
});
