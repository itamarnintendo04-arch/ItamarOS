/* Browser-only offline cache for static ItamarOS resources. No native OS updates. */
const CACHE='itamaros-static-0.4.0';
const FILES=['/','/index.html','/apps/addons.css?v=0.4.0','/apps/player.js?v=0.4.0','/apps/games.js?v=0.4.0','/apps/updates.js?v=0.4.0','/assets/itamaros-icon.svg','/manifest.webmanifest','/downloads.html','/setup.html'];
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)));self.skipWaiting()});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('itamaros-static-')&&key!==CACHE).map(key=>caches.delete(key)))));self.clients.claim()});
self.addEventListener('fetch',event=>{
 const request=event.request;
 if(request.method!=='GET'||new URL(request.url).origin!==self.location.origin)return;
 if(request.mode==='navigate'){
  event.respondWith(fetch(request).then(response=>{if(response.ok){const clone=response.clone();caches.open(CACHE).then(c=>c.put(request,clone))}return response}).catch(()=>caches.match(request).then(r=>r||caches.match('/index.html'))));return
 }
 event.respondWith(caches.match(request).then(cached=>cached||fetch(request).then(response=>{if(response.ok&&response.type==='basic'){const clone=response.clone();caches.open(CACHE).then(c=>c.put(request,clone))}return response})))
});
