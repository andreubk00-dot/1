/* Endless Defenders v1.8.17 offline PWA */
const CACHE_NAME='ed-mobile-v1.8.17';
const PRECACHE=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png',
'./audio/laserSmall_000.ogg','./audio/laserSmall_001.ogg','./audio/laserSmall_002.ogg','./audio/laserSmall_004.ogg',
'./audio/laserLarge_000.ogg','./audio/laserLarge_001.ogg','./audio/laserLarge_002.ogg','./audio/forceField_000.ogg',
'./audio/thrusterFire_000.ogg','./audio/explosionCrunch_002.ogg','./audio/explosionCrunch_004.ogg',
'./audio/menu_theme.ogg','./audio/battle_theme.ogg'];
self.addEventListener('install',event=>{
 event.waitUntil((async()=>{
 const cache=await caches.open(CACHE_NAME);
 await cache.addAll(PRECACHE.slice(0,5));
 await Promise.allSettled(PRECACHE.slice(5).map(async url=>{try{await cache.add(url);}catch(err){console.warn('Media cache failed',url,err);}}));
 await self.skipWaiting();
 })());
});
self.addEventListener('activate',event=>{
 event.waitUntil((async()=>{const names=await caches.keys();await Promise.all(names.filter(n=>n.startsWith('ed-mobile-')&&n!==CACHE_NAME).map(n=>caches.delete(n)));await self.clients.claim();})());
});
self.addEventListener('fetch',event=>{
 const req=event.request;
 if(req.method!=='GET')return;
 const url=new URL(req.url);
 if(url.origin!==self.location.origin)return;
 if(req.mode==='navigate'){
 event.respondWith((async()=>{try{const live=await fetch(req);if(live.ok){const cache=await caches.open(CACHE_NAME);cache.put('./index.html',live.clone()).catch(()=>{});}return live;}
 catch(err){const cache=await caches.open(CACHE_NAME);return await cache.match('./index.html')||Response.error();}})());
 return;
 }
 event.respondWith((async()=>{const cache=await caches.open(CACHE_NAME);const saved=await cache.match(req,{ignoreSearch:true});if(saved)return saved;
 try{const live=await fetch(req);if(live.ok)cache.put(req,live.clone()).catch(()=>{});return live;}catch(err){return Response.error();}})());
});