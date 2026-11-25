const CACHE_NAME = "grand-partage-shell-v50-password-current-20261125";
const SHELL = [
  "/le-grand-partage/",
  "/le-grand-partage/manifest.webmanifest?v=official-image-20261123-1",
  "/le-grand-partage/Le_Grand_Partage_logo_512(1).jpg?v=official-image-20261123-1"
];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("push", event => {
  let payload = {title:"Le Grand Partage",body:"Vous avez reçu un nouveau message.",url:"/le-grand-partage/"};
  try { if(event.data) payload={...payload,...event.data.json()}; } catch {}
  event.waitUntil(self.registration.showNotification(payload.title,{body:payload.body,icon:"/le-grand-partage/Le_Grand_Partage_logo_512(1).jpg",badge:"/le-grand-partage/Le_Grand_Partage_logo_512(1).jpg",data:{url:payload.url},tag:payload.tag||"lgp-notification",renotify:true}));
});
self.addEventListener("notificationclick",event=>{
  event.notification.close();
  const target=new URL(event.notification.data?.url||"/le-grand-partage/",self.location.origin).href;
  event.waitUntil(clients.matchAll({type:"window",includeUncontrolled:true}).then(list=>{
    for(const client of list){if(client.url.startsWith(self.location.origin)){client.focus();client.navigate(target);return;}}
    return clients.openWindow(target);
  }));
});
self.addEventListener("fetch", event => {
  if(event.request.method!=="GET"||new URL(event.request.url).origin!==self.location.origin)return;
  event.respondWith(fetch(event.request).then(response=>{if(response.ok){const copy=response.clone();caches.open(CACHE_NAME).then(cache=>cache.put(event.request,copy));}return response;}).catch(()=>caches.match(event.request).then(cached=>cached||caches.match("/le-grand-partage/"))));
});
