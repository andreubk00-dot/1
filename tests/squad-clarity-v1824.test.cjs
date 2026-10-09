'use strict';
// Read-only squad explanation should mirror the EXACT battle synergy resolver.
// No suggestions for unowned units and no changes to save schema/economy.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
const a=scripts(pc),b=scripts(mobile);
assert.equal(a[1],b[1],'PC/iPhone game scripts diverged');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook));
const win={};
new Function('window','document','navigator','performance',
 a[0]+'\n'+a[1].replace(hook,'window.__squadQa={Game,DEFAULT_SAVE,TEXT,DEFENDERS};')
)(win,{}, {language:'ru'},{now:()=>0});
const {Game,DEFAULT_SAVE,TEXT,DEFENDERS}=win.__squadQa;
function fixture(lang){
 const g=Object.create(Game.prototype);g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));
 g.lang=lang;g.t=TEXT[lang];g.persist=()=>{};g.renderHome=()=>{};
 return g;
}
const g=fixture('ru');
const initial=JSON.stringify(g.save),base=g.squadSummaryData();
assert.deepEqual(base.ids,['sentinel','spark','frost']);
assert.equal(base.synergy.id,'bulwark');
assert.equal(base.replaced,g.t.unitSentinel);
assert.deepEqual(base.names,['Страж','Искра','Крио']);
assert.equal(JSON.stringify(g.save),initial,'Read-only summary changed saved progress');
// Active synergy cannot reveal a locked unit accidentally.
g.save.selected=['spark','prism','ember'];
let hidden=g.squadSummaryData();
assert.deepEqual(hidden.ids,['spark']);
assert.equal(hidden.synergy.id,'none');
assert.equal(hidden.replaced,null);
const beforeUnlock=JSON.stringify(g.save);
g.save.unlocked.push('prism','ember');
assert.equal(g.squadSummaryData().synergy.id,'cascade');
assert.equal(g.squadSummaryData().replaced,'Искра');
assert.equal(JSON.stringify(g.save),JSON.stringify({...JSON.parse(beforeUnlock),unlocked:g.save.unlocked}));
g.selectDefender('sentinel'); // Same first-slot rotation as live game.
assert.deepEqual(g.save.selected,['prism','ember','sentinel']);
assert.equal(g.squadSummaryData().synergy.id,'none');
assert.equal(g.squadSummaryData().replaced,'Призма');
g.selectDefender('not-a-defender');
assert.deepEqual(g.save.selected,['prism','ember','sentinel']);
const en=fixture('en');en.save.unlocked.push('prism','ember');
en.save.selected=['spark','prism','ember'];
assert.equal(en.squadSummaryData().synergy.id,'cascade');
assert.equal(en.squadSummaryData().replaced,'Spark');
assert(en.squadSummaryData().synergy.desc.includes('chain'));
for(const combo of [
 ['sentinel','spark','frost'],['spark','prism','ember'],['sentinel','spark','prism'],
 ['sentinel','frost','nova'],['spark','prism','volt'],['frost','ember','chrono'],
 ['sentinel','nova','ember'],['frost','nova','ember']
]){
 const t=fixture('ru');t.save.unlocked=[...new Set([...t.save.unlocked,...combo])];t.save.selected=combo;
 const summary=t.squadSummaryData();
 assert.equal(summary.synergy.id,t.activeSynergy(combo).id,'UI description and actual combat disagree');
 assert.equal(summary.names.length,3);
 assert(summary.names.every(Boolean));
}
for(const html of [pc,mobile]){
 assert(html.includes('id="collectionSquadSummary"'));
 assert(html.includes('aria-live="polite"'));
 assert(html.includes('data-active-synergy='));
 assert(html.includes('collection-squad-summary'));
 assert(html.includes('При выборе нового защитника заменится'));
 assert(html.includes('Selecting another defender replaces'));
}
assert.equal(DEFAULT_SAVE.version,21);
assert.equal(Object.keys(DEFENDERS).length,8);
console.log('PASS squad-preview parity, localization, no hidden units and no resource mutation');
