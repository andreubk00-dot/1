'use strict';
// Rebranding must not reset installed games or existing progress.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const pc=fs.readFileSync(path.join(ROOT,'pc','index.html'),'utf8');
const iphone=fs.readFileSync(path.join(ROOT,'iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
assert.equal(scripts(pc)[1],scripts(iphone)[1],'PC/mobile gameplay scripts must match');
for(const [name,s] of [['pc',pc],['iphone',iphone]]){
  assert(s.includes('<h1>Riftoryn: Core Defense</h1>'),name+' loading screen old brand');
  assert(s.includes("title:'Riftoryn: Core Defense'"),name+' localized title old brand');
  assert(s.includes('content="Riftoryn: Core Defense"'),name+' app metadata old brand');
  assert(s.includes('Riftoryn: Core Defense —'),name+' document title old brand');
  assert(s.includes('endless_defenders_save_v1'),name+' legacy save key lost');
  assert(s.includes('out.version=21'),name+' changed save schema');
  assert(!s.includes('Бесконечные защитники'),name+' old player-facing title');
  assert(!s.includes("title:'Endless Defenders'"),name+' old English title');
}
const manifest=JSON.parse(fs.readFileSync(path.join(ROOT,'iphone','manifest.webmanifest'),'utf8'));
assert.equal(manifest.name,'Riftoryn: Core Defense');
assert.equal(manifest.short_name,'Riftoryn');
assert.equal(manifest.id,'./','Changing PWA identity would orphan existing installs');
const sw=fs.readFileSync(path.join(ROOT,'iphone','service-worker.js'),'utf8');
assert(sw.includes('ed-mobile-v1.8.24-riftoryn-rebrand1'),'New name could be hidden by stale PWA cache');
const vk=fs.readFileSync(path.join(ROOT,'tools','build-vk-games.cjs'),'utf8');
assert(vk.includes("'<title>Riftoryn: Core Defense — '+name+' v1.8.24</title>'"),'VK/OK builds not rebranded');
assert(vk.includes("'endless_defenders_'+platform+'_save_v1'"),'VK/OK legacy save keys changed');
console.log('PASS browser/PWA/SDK brand, v21 save continuity and VK/OK builder');
