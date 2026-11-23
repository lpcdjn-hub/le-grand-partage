const CACHE_NAME = "grand-partage-shell-v42-official-image-20261123";
const SHELL = [
  "/le-grand-partage/",
  "/le-grand-partage/manifest.webmanifest?v=official-image-20261123-1",
  "/le-grand-partage/Le_Grand_Partage_logo_512(1).jpg?v=official-image-20261123-1",
  "/le-grand-partage/Le_Grand_Partage_logo_512(1).jpg?v=official-image-20261123-1",
];
self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});
self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET" || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith(
    fetch(event.request).then(response => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy));
      }
      return response;
    }).catch(() => caches.match(event.request).then(cached => cached || caches.match("/le-grand-partage/")))
  );
});
