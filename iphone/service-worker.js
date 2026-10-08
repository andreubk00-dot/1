/* Endless Defenders v1.8.18 offline PWA */
const CACHE_NAME='ed-mobile-v1.8.18';
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
 if(!self.registration.active)await self.skipWaiting();
 })());
});
self.addEventListener('message',event=>{
 if(event.data?.type==='ACTIVATE_UPDATE'&&event.source)event.waitUntil(self.skipWaiting());
});
self.addEventListener('activate',event=>{
 event.waitUntil((async()=>{const names=await caches.keys();await Promise.all(names.filter(n=>n.startsWith('ed-mobile-')&&n!==CACHE_NAME).map(n=>caches.delete(n)));await self.clients.claim();})());
});
// Safari media fetches may request byte ranges. Answer from the cached
// complete audio with a compliant 206 Partial Content response.
async function cachedRange(request,cached){
  const range=request.headers.get('range');
  if(!range)return cached;
  const match=/^bytes=(\d*)-(\d*)$/.exec(range.trim());
  if(!match)return cached;
  const bytes=await cached.arrayBuffer(),total=bytes.byteLength;
  let start,end;
  if(match[1]===''){
    const suffix=Number(match[2]);
    if(!Number.isSafeInteger(suffix)||suffix<1)return new Response(null,{status:416,headers:{'Content-Range':'bytes */'+total}});
    start=Math.max(0,total-suffix);end=total-1;
  }else{
    start=Number(match[1]);end=match[2]?Number(match[2]):total-1;
  }
  if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start<0||start>end||start>=total)return new Response(null,{status:416,headers:{'Content-Range':'bytes */'+total}});
  end=Math.min(end,total-1);
  const headers=new Headers(cached.headers);
  headers.set('Content-Range','bytes '+start+'-'+end+'/'+total);
  headers.set('Content-Length',String(end-start+1));
  headers.set('Accept-Ranges','bytes');
  return new Response(bytes.slice(start,end+1),{status:206,statusText:'Partial Content',headers});
}
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
 event.respondWith((async()=>{const cache=await caches.open(CACHE_NAME);const saved=await cache.match(req,{ignoreSearch:true});if(saved)return url.pathname.includes('/audio/')?cachedRange(req,saved):saved;
 try{const live=await fetch(req);if(live.status===200)cache.put(req,live.clone()).catch(()=>{});return live;}catch(err){return Response.error();}})());
});