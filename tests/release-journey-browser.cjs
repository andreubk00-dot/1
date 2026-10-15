'use strict';
// Browser release-journey QA: scripted transitions through real game UI.
// Wave depth is set explicitly for a deterministic relic/result fixture; this
// does NOT claim a complete unassisted playthrough.
const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'), path=require('node:path');
const profiles=[
  {name:'desktop-chromium',browser:chromium,port:4173,width:1366,height:768},
  {name:'laptop-chromium',browser:chromium,port:4173,width:1024,height:600},
  {name:'mobile-390-chromium',browser:chromium,port:4174,width:390,height:844},
  {name:'mobile-320-chromium',browser:chromium,port:4174,width:320,height:568},
  {name:'landscape-844-chromium',browser:chromium,port:4174,width:844,height:390},
  {name:'mobile-390-webkit',browser:webkit,port:4174,width:390,height:844},
  {name:'landscape-844-webkit',browser:webkit,port:4174,width:844,height:390}
];
const dest='screenshots/release-journey',audit=[];
fs.mkdirSync(dest,{recursive:true});
async function checkPanel(page,name,stage,selector,actions){
 const data=await page.evaluate(({selector,actions})=>{
   const card=document.querySelector(selector);
   if(!card)return {error:'no modal card '+selector};
   const viewport={w:innerWidth,h:innerHeight};
   const rect=el=>{const b=el.getBoundingClientRect();return {x:+b.x.toFixed(1),y:+b.y.toFixed(1),w:+b.width.toFixed(1),h:+b.height.toFixed(1),right:+b.right.toFixed(1),bottom:+b.bottom.toFixed(1)}};
   const buttons=[...card.querySelectorAll('button')].filter(el=>el.getClientRects().length).map(el=>({id:el.id||el.dataset.relic||el.textContent.trim().slice(0,24),rect:rect(el)}));
   return {viewport,card:rect(card),clientWidth:card.clientWidth,scrollWidth:card.scrollWidth,clientHeight:card.clientHeight,scrollHeight:card.scrollHeight,overflowX:getComputedStyle(card).overflowX,overflowY:getComputedStyle(card).overflowY,buttons,visible:!card.closest('.hidden')};
 },{selector,actions});
 audit.push({name,stage,...data});
 await page.screenshot({path:path.join(dest,name+'-'+stage+'.png')});
 assert(data.visible&&!data.error,'Missing visible '+stage+': '+JSON.stringify(data));
 assert(data.card.w>150&&data.card.h>100,'Collapsed '+stage+' dialog');
 assert(data.card.x>=-4&&data.card.right<=data.viewport.w+4,
   'Dialog outside horizontal viewport '+name+' '+stage+': '+JSON.stringify(data));
 // Decorative clipped :before/:after pseudo-elements can increase scrollWidth
 // while the actual text and buttons remain inside the clip boundary.
 assert(data.scrollWidth<=data.clientWidth+5||['hidden','clip'].includes(data.overflowX),
   'Horizontal scrolling in dialog '+name+' '+stage+': '+JSON.stringify(data));
 if(data.scrollHeight>data.clientHeight+5)assert(['auto','scroll'].includes(data.overflowY),
   'Tall dialog has unreachable controls '+name+' '+stage+': '+JSON.stringify(data));
 for(const id of actions) {
   const el=page.locator(id);
   if(await el.count() && await el.isVisible()) {
     await el.scrollIntoViewIfNeeded();
     const b=await el.boundingBox();
     assert(b&&b.width>=25&&b.height>=20&&b.x>=-4&&b.x+b.width<=data.viewport.w+4&&b.y>=-4&&b.y+b.height<=data.viewport.h+4,
       'Control not usable '+name+' '+stage+' '+id+': '+JSON.stringify(b));
   }
 }
 return data;
}
// A visible button can still be obscured by an unrelated overlay.
// Probe the real hit target after scrolling into view, not just its rectangle.
async function assertClickable(page,selector,stage){
 const loc=page.locator(selector).first();
 assert(await loc.isVisible(),stage+' control not visible: '+selector);
 await loc.scrollIntoViewIfNeeded();
 const hit=await loc.evaluate(el=>{
   const r=el.getBoundingClientRect(),x=Math.max(0,Math.min(innerWidth-1,r.left+r.width/2)),
       y=Math.max(0,Math.min(innerHeight-1,r.top+r.height/2));
   const top=document.elementFromPoint(x,y);
   return {target:top?.id||top?.className||top?.tagName,clickable:!!top&&(el===top||el.contains(top)),center:[x,y]};
 });
 assert(hit.clickable,stage+' control intercepted: '+selector+' '+JSON.stringify(hit));
}
async function run(profile){
 const browser=await profile.browser.launch({headless:true});
 const context=await browser.newContext({viewport:{width:profile.width,height:profile.height},serviceWorkers:'block',
     locale:'ru-RU',hasTouch:profile.width<=844,reducedMotion:'reduce'});
 const page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 try{
   await page.goto('http://127.0.0.1:'+profile.port+'/',{waitUntil:'domcontentloaded',timeout:30000});
   await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__&&!document.querySelector('#shell').classList.contains('hidden'),null,{timeout:25000});
   assert(await page.locator('#playBtn').isVisible(),'Play not visible');
   await page.evaluate(()=>{const g=window.__ENDLESS_DEFENDERS__;g.save.tutorialDone=true;g.audio.enabled=false;});
   for(const [id,button] of [['labScreen','#labBtn'],['collectionScreen','#collectionBtn']]){
     await page.locator(button).click();
     await checkPanel(page,profile.name,id,'#'+id+' .modal-card',['#'+id+' .close-btn']);
     // First-time contextual coaching is intentionally modal and must be
     // acknowledged through its real Continue control before closing the parent.
     if(await page.locator('#coachScreen').isVisible()){
       assert(await page.locator('#coachContinueBtn').isVisible(),'Coach missing acknowledgment');
       await page.locator('#coachContinueBtn').click();
       assert(!(await page.locator('#coachScreen').isVisible()),'Coach did not close');
     }
     await assertClickable(page,'#'+id+' .close-btn',id+' close');
     await page.locator('#'+id+' .close-btn').click();
     assert(!(await page.locator('#'+id).isVisible()),'Cannot close '+id);
   }
   await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.startRun(false));
   await page.waitForTimeout(500); 
   assert(await page.locator('#gameCanvas').isVisible(),'Battle missing');
   await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.togglePauseOverlay(true));
   assert(await page.locator('#pauseScreen').isVisible(),'Pause missing');
   assert((await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.paused)),'Combat runs under pause overlay');
   await checkPanel(page,profile.name,'pause','#pauseScreen .modal-card',['#resumeBtn','#exitRunBtn']);
   await assertClickable(page,'#resumeBtn','pause resume');
   await page.locator('#resumeBtn').click();
   assert(!(await page.locator('#pauseScreen').isVisible()),'Pause did not close');
   // A deterministic wave-five fixture tests real relic UI and save transitions.
   await page.evaluate(()=>{
     const g=window.__ENDLESS_DEFENDERS__;
     g.run.wave=5;g.run.lastCleared=4;g.run.kills=36;
     g.presentRelicChoice();
   });
   assert(await page.locator('#relicScreen').isVisible(),'Relic choice missing');
   const initial=await page.locator('[data-relic]').count();
   assert.equal(initial,3,'Expected three relic choices');
   await checkPanel(page,profile.name,'relic','#relicScreen .modal-card',['#relicRerollBtn','[data-relic]:first-child']);
   const before=await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.run.rerolls);
   if(before>0){
     await assertClickable(page,'#relicRerollBtn','relic reroll');
     await page.locator('#relicRerollBtn').click();
     assert.equal(await page.locator('[data-relic]').count(),3,'Reroll broke relic choices');
     assert.equal(await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.run.rerolls),before-1,'Reroll did not debit count');
     await checkPanel(page,profile.name,'relic-reroll','#relicScreen .modal-card',['[data-relic]:first-child']);
   }
   await assertClickable(page,'[data-relic]','relic choice');
   await page.locator('[data-relic]').first().click();
   const selected=await page.evaluate(()=>({paused:window.__ENDLESS_DEFENDERS__.paused,
     count:window.__ENDLESS_DEFENDERS__.run.relics.length}));
   assert(selected.count===1&&!selected.paused,'Relic selection did not resume combat');
   assert(!(await page.locator('#relicScreen').isVisible()),'Relic modal remains over combat');
   await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.endRun(true));
   assert(await page.locator('#resultScreen').isVisible(),'Result screen not shown');
   await page.waitForTimeout(480); // do not snapshot the opening opacity animation
   const earned=await page.evaluate(()=>({shards:window.__ENDLESS_DEFENDERS__.save.shards,
      gems:window.__ENDLESS_DEFENDERS__.save.gems,version:window.__ENDLESS_DEFENDERS__.save.version,
      completed:window.__ENDLESS_DEFENDERS__.run.completed}));
   assert.equal(earned.version,21,'Save version changed');
   assert.equal(earned.completed,4,'Run result wave depth drifted');
   await checkPanel(page,profile.name,'result','#resultScreen .modal-card',['#resultContinueBtn','#doubleRewardBtn']);
   // A new record can unlock a first-time contextual tip over the results.
   if(await page.locator('#coachScreen').isVisible()){
     assert(await page.locator('#coachContinueBtn').isVisible(),'Result coach lacks dismiss action');
     await page.locator('#coachContinueBtn').click();
     assert(!(await page.locator('#coachScreen').isVisible()),'Result coach failed to dismiss');
   }
   await assertClickable(page,'#resultContinueBtn','results continue');
   await page.locator('#resultContinueBtn').click();
   await page.waitForTimeout(150);
   assert(await page.locator('#homeScreen').isVisible(),'Cannot return home after result');
   await page.reload({waitUntil:'domcontentloaded'});
   await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__,null,{timeout:25000});
   const reloaded=await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.save);
   assert.equal(reloaded.version,21);
   assert.equal(reloaded.shards,earned.shards,'Shards lost after completed run');
   assert.equal(reloaded.gems,earned.gems,'Gems lost after completed run');
   assert.deepEqual(errors,[],'JS exceptions '+profile.name+': '+errors.join('; '));
   console.log('PASS release journey '+profile.name+' earned '+JSON.stringify(earned));
 }finally{await context.close();await browser.close();}
}
(async()=>{for(const p of profiles)await run(p);fs.writeFileSync(path.join(dest,'report.json'),JSON.stringify(audit,null,2));})()
 .catch(e=>{console.error(e);process.exitCode=1;});
