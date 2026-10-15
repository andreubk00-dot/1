'use strict';
const {chromium}=require('playwright'), fs=require('fs');
const profiles=[
 ['desktop',1366,768,4173],['laptop',1024,600,4173],
 ['mobile-landscape',844,390,4174],['mobile-short',667,375,4174],
 ['mobile-tight',568,320,4174],['mobile-portrait',390,844,4174],
 ['small-portrait',320,568,4174]
];
const sels=['.brand','.resources','.hud-top','.hud-top .hud-pill','.hud-bottom','#unitCards','#skillBtn','#bossHud','#bossObjective','#waveBanner','#comboHud','#riftHud','#fieldOrderHud','#commanderCombatHud'];
const area=(a,b)=>Math.max(0,Math.min(a.r,b.r)-Math.max(a.l,b.l))*Math.max(0,Math.min(a.b,b.b)-Math.max(a.t,b.t));
const pairs=[['.brand','.resources'],['.hud-top .hud-pill','.hud-top .hud-pill'],['#unitCards','#commanderCombatHud'],['#skillBtn','#commanderCombatHud'],['#bossHud','#bossObjective'],['#bossHud','#waveBanner'],['#bossObjective','#waveBanner'],['#bossObjective','#commanderCombatHud'],['#bossObjective','#unitCards'],['#bossObjective','#skillBtn'],['#fieldOrderHud','#bossHud'],['#fieldOrderHud','#bossObjective'],['#fieldOrderHud','#commanderCombatHud'],['#comboHud','#bossHud'],['#comboHud','#bossObjective'],['#comboHud','#fieldOrderHud'],['#riftHud','#fieldOrderHud']];
const report=[];
fs.mkdirSync('screenshots/hud-qa',{recursive:true});
async function probe(page,name,phase){
 const v=await page.evaluate(sels=>{const m={};for(const s of sels){m[s]=[...document.querySelectorAll(s)].filter(x=>x.getClientRects().length&&!x.closest('.hidden')&&getComputedStyle(x).visibility!=='hidden').map(x=>{const r=x.getBoundingClientRect();return {l:Math.round(r.left),r:Math.round(r.right),t:Math.round(r.top),b:Math.round(r.bottom),w:Math.round(r.width),h:Math.round(r.height)};});}return {m,w:innerWidth,h:innerHeight,scrollWidth:document.documentElement.scrollWidth}},sels);
 const hits=[];
 for(const [a,b] of pairs)for(let i=0;i<(v.m[a]||[]).length;i++)for(let j=0;j<(v.m[b]||[]).length;j++){if(a===b&&j<=i)continue;const z=area(v.m[a][i],v.m[b][j]);if(z>24)hits.push({a,b,area:z,first:v.m[a][i],second:v.m[b][j]});}
 for(const [sel,rr] of Object.entries(v.m))for(const r of rr){if(r.w>0&&r.h>0&&(r.l< -4||r.r>v.w+4||r.t< -4||r.b>v.h+4))hits.push({outOfBounds:sel,rect:r});}
 if(phase==='boss' && !(v.m['#bossHud']||[]).length)hits.push({outOfBounds:'bossHud unexpectedly hidden during boss QA'});
 if(phase==='boss' && !(v.m['#bossObjective']||[]).length)hits.push({outOfBounds:'boss objective unexpectedly hidden during boss QA'});
 const data={view:name,phase,viewport:[v.w,v.h],scrollWidth:v.scrollWidth,hits};report.push(data);console.log('HUD_AUDIT '+JSON.stringify(data));
 await page.screenshot({path:'screenshots/hud-qa/'+name+'-'+phase+'.png'});
}
async function run([name,w,h,port]){
 const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:w,height:h},locale:'ru-RU',reducedMotion:'reduce',serviceWorkers:'block'}),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 try{
 await page.goto('http://127.0.0.1:'+port+'/',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__&&!document.getElementById('shell').classList.contains('hidden'));
 await probe(page,name,'home');
 await page.evaluate(()=>{const g=window.__ENDLESS_DEFENDERS__;g.save.tutorialDone=true;g.audio.enabled=false;g.startRun(false);g.updateBattleHud();});
 await page.waitForTimeout(180);await probe(page,name,'battle');
 await page.evaluate(()=>{const g=window.__ENDLESS_DEFENDERS__;g.paused=true;const b=document.getElementById('bossHud');b.classList.remove('hidden');document.getElementById('comboHud').classList.remove('hidden');document.getElementById('bossName').textContent='АЭГИДА-10';document.getElementById('bossAbility').textContent='Фазовая броня';const e={boss:g.bossSpec(100),hp:100,maxHp:100,weakCooldown:0,weakOpen:1};g.run.interactives=[];g.updateBossObjective(e);});
 await probe(page,name,'boss');
 await page.evaluate(()=>{for(const id of ['bossHud','comboHud','bossObjective'])document.getElementById(id).classList.add('hidden');for(const id of ['fieldOrderHud','riftHud'])document.getElementById(id).classList.remove('hidden');});
 await probe(page,name,'notices');
 await page.evaluate(()=>{for(const id of ['fieldOrderHud','riftHud'])document.getElementById(id).classList.add('hidden');const g=window.__ENDLESS_DEFENDERS__;document.getElementById('collectionScreen').classList.remove('hidden');g.renderCollection();});
 await page.screenshot({path:'screenshots/hud-qa/'+name+'-squad.png'});
 if(errors.length)throw new Error(name+' JS errors: '+errors.join(' / '));
 }finally{await browser.close();}
}
(async()=>{for(const p of profiles)await run(p);fs.writeFileSync('screenshots/hud-qa/report.json',JSON.stringify(report,null,2));const problems=report.filter(x=>x.hits.length);if(problems.length)throw new Error('HUD overlaps or clipped elements: '+JSON.stringify(problems.map(x=>({view:x.view,phase:x.phase,hits:x.hits.map(v=>({a:v.a,b:v.b,area:v.area,outOfBounds:v.outOfBounds}))}))));})().catch(e=>{console.error(e);process.exitCode=1});
