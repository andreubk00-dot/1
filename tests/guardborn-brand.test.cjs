'use strict';
// Branding-only regression. Do not rename the existing v21 save formats,
// localStorage namespaces or the JS testing bridge when changing display text.
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.join(__dirname,'..');
for(const platform of ['pc','iphone']){
  const html=fs.readFileSync(path.join(root,platform,'index.html'),'utf8');
  assert(html.includes('<title>Guardborn —'),'Browser title missing for '+platform);
  assert(html.includes('name="application-name" content="Guardborn"'));
  assert(html.includes('name="apple-mobile-web-app-title" content="Guardborn"'));
  assert(html.includes('<h1>Guardborn</h1>'));
  assert(html.includes("title:'Guardborn'"),'Russian/English UI name missing for '+platform);
  assert(!html.includes('Бесконечные защитники'));
  assert(!html.includes('Endless Defenders'));
  assert(html.includes('endless_defenders_save_v1'),'Legacy save key must survive');
  assert(html.includes("format:'endless-defenders-save'"),'Export format must survive');
  assert(html.includes('window.__ENDLESS_DEFENDERS__'),'External test bridge must survive');
  assert(html.includes('out.version=21'),'Save v21 schema must survive');
}
const manifest=JSON.parse(fs.readFileSync(path.join(root,'iphone','manifest.webmanifest'),'utf8'));
assert.equal(manifest.name,'Guardborn');
assert.equal(manifest.short_name,'Guardborn');
assert.equal(manifest.id,'./','PWA identity must not change');
const sw=fs.readFileSync(path.join(root,'iphone','service-worker.js'),'utf8');
assert(sw.includes("CACHE_NAME='ed-mobile-v1.8.24-guardborn'"),'Old offline cache must be refreshed');
assert(sw.includes("n.startsWith('ed-mobile-')"),'Legacy cache cleanup must survive');
console.log('PASS Guardborn brand identity, save format and existing PWA identity');
