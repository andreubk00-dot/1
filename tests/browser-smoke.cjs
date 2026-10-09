'use strict';
// Real Chromium + WebKit smoke checks; WebKit is NOT a physical iPhone Safari test.
// Run from repository root after: npm install --no-save playwright
//                                   npx playwright install --with-deps chromium webkit
//                                   python3 -m http.server 4173 --directory pc &
//                                   python3 -m http.server 4174 --directory iphone &
const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict');
const profiles=[
  {name:'desktop-chromium',engine:chromium,port:4173,width:1366,height:768,mobile:false},
  {name:'phone-320-chromium',engine:chromium,port:4174,width:320,height:568,mobile:true},
  {name:'phone-390-chromium',engine:chromium,port:4174,width:390,height:844,mobile:true},
  {name:'phone-390-webkit',engine:webkit,port:4174,width:390,height:844,mobile:true},
  {name:'phone-landscape-webkit',engine:webkit,port:4174,width:844,height:390,mobile:true}
];
async function smoke(profile){
 const browser=await profile.engine.launch({headless:true});
 const context=await browser.newContext({viewport:{width:profile.width,height:profile.height},
    hasTouch:profile.mobile,isMobile:profile.mobile&&profile.engine===chromium,
    serviceWorkers:'block',locale:'ru-RU',reducedMotion:'reduce'});
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 try{
  await page.goto('http://127.0.0.1:'+profile.port+'/',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__,null,{timeout:25000});
  await page.waitForSelector('#shell:not(.hidden)',{timeout:25000});
  assert(await page.locator('#playBtn').isVisible(),'Main play button missing');
  assert(await page.locator('#shardChip').isVisible(),'Shard resource missing');
  await page.locator('#shardChip').click();
  assert(await page.locator('#resourceHelpScreen').isVisible(),'Resource dialog failed to open');
  await page.locator('#resourceHelpClose').click();
  assert(!(await page.locator('#resourceHelpScreen').isVisible()),'Resource dialog failed to close');
  // Long-term contract goal is visible without changing prices or balances.
  const contractGoal=page.locator('[data-contract-goal="prism"]');
  assert(await contractGoal.isVisible(),'Prism long-term contract goal missing');
  assert.equal(await contractGoal.locator('.contract-goal-meter').count(),4,'Not all permanent resource meters are shown');
  const goalCheck=await page.evaluate(()=>{
    const g=window.__ENDLESS_DEFENDERS__,before=JSON.stringify(g.save);
    const node=document.querySelector('[data-contract-goal="prism"]');
    const width=node?.getBoundingClientRect().width||0;
    return {unchanged:before===JSON.stringify(g.save),width,scrollWidth:document.documentElement.scrollWidth,viewport:innerWidth};
  });
  assert(goalCheck.unchanged&&goalCheck.width>20,'Contract goal mutated resources or failed to render');
  assert(goalCheck.scrollWidth<=goalCheck.viewport+6,'Contract goal caused mobile overflow');
  // The squad collection now explains the currently active combat synergy on
  // mobile too. Test live selection behavior, then restore the original save.
  const squad=await page.evaluate(()=>{
    const g=window.__ENDLESS_DEFENDERS__,modal=document.getElementById('collectionScreen'),
      summary=document.getElementById('collectionSquadSummary');
    const original={selected:g.save.selected.slice(),unlocked:g.save.unlocked.slice()};
    modal.classList.remove('hidden');
    g.renderCollection();
    const first={id:summary.querySelector('[data-active-synergy]')?.dataset.activeSynergy,
      text:summary.textContent,visible:summary.getBoundingClientRect().width>30};
    g.save.unlocked=[...new Set([...g.save.unlocked,'prism','ember'])];
    g.save.selected=['spark','prism','ember'];
    g.renderCollection();
    const combo={id:summary.querySelector('[data-active-synergy]')?.dataset.activeSynergy,
      text:summary.textContent};
    g.selectDefender('sentinel');
    const rotated={id:summary.querySelector('[data-active-synergy]')?.dataset.activeSynergy,
      names:g.save.selected.slice(),text:summary.textContent};
    g.save.selected=original.selected;g.save.unlocked=original.unlocked;
    g.persist();g.renderCollection();
    const layout={width:summary.clientWidth,scroll:summary.scrollWidth,
      pageScroll:document.documentElement.scrollWidth,viewport:innerWidth};
    return {first,combo,rotated,layout};
  });
  assert(squad.first.visible&&squad.first.id==='bulwark','Starter synergy summary missing');
  assert.equal(squad.combo.id,'cascade','Collection ignored actual synergy after role change');
  assert(squad.combo.text.includes('Искра'),'Summary lacks replacement-role explanation');
  assert.equal(squad.rotated.id,'none','Squad swap did not refresh active synergy');
  assert.deepEqual(squad.rotated.names,['prism','ember','sentinel'],'First slot replacement drifted');
  assert(squad.layout.width>50&&squad.layout.scroll<=squad.layout.width+4,
    'Squad summary overflows its mobile container: '+JSON.stringify(squad.layout));
  assert(squad.layout.pageScroll<=squad.layout.viewport+6,
    'Squad collection causes horizontal page overflow');
  await page.screenshot({path:'screenshots/'+profile.name+'-squad.png',fullPage:true});
  await page.evaluate(()=>document.getElementById('collectionScreen').classList.add('hidden'));
  const result=await page.evaluate(()=>{
    const g=window.__ENDLESS_DEFENDERS__;g.save.tutorialDone=true;
    g.audio.enabled=false;g.startRun(false);
    // The affordance must work without hover on a 320px touch display.
    const upgradeButton=document.querySelector('[data-unit="0"]');
    const unit=g.run.units[0],cost=g.unitUpgradeCost(unit),beforeLevel=unit.level;
    g.run.energy=Math.max(0,cost-9);g.updateBattleHud();
    const unavailable={status:upgradeButton.querySelector('.unit-affordance')?.textContent,
      next:upgradeButton.querySelector('.unit-next-level')?.textContent,
      blocked:upgradeButton.classList.contains('needs-energy'),
      label:upgradeButton.getAttribute('aria-label')};
    g.run.energy=cost+1;g.updateBattleHud();
    const available={status:upgradeButton.querySelector('.unit-affordance')?.textContent,
      ready:upgradeButton.classList.contains('can-upgrade'),
      label:upgradeButton.getAttribute('aria-label')};
    upgradeButton.click();
    const purchased={level:unit.level,energy:g.run.energy,
      next:document.querySelector('[data-unit="0"] .unit-next-level')?.textContent,
      status:document.querySelector('[data-unit="0"] .unit-affordance')?.textContent};
    const cardRects=[...document.querySelectorAll('[data-unit]')].map(btn=>{
      const card=btn.getBoundingClientRect(),meta=btn.querySelector('.unit-upgrade-meta');
      return {left:card.left,right:card.right,width:card.width,
        metaWidth:meta?.clientWidth||0,metaScroll:meta?.scrollWidth||0};
    });
    const upgrade={cost,beforeLevel,unavailable,available,purchased,cardRects};
    const before=g.run.skillCd;g.usePulse();
    const pulse=g.run.skillCd>before&&g.run.skills===1;
    g.setRmbBoost(true);const speed=g.effectiveSpeed();
    g.setRmbBoost(false);const ended=g.effectiveSpeed();
    g.save.shards=1234;g.persist(true);
    const skill=document.getElementById('skillBtn').getBoundingClientRect();
    const canvas=document.getElementById('gameCanvas').getBoundingClientRect();
    return {upgrade,running:g.inRun,wave:g.run.wave,pulse,speed,ended,saveVersion:g.save.version,
      skill:{width:skill.width,left:skill.left,right:skill.right},
      canvas:{width:canvas.width,height:canvas.height},width:innerWidth,
      scrollWidth:document.documentElement.scrollWidth};
  });
  assert(result.running&&result.wave===1,'Battle did not start');
  assert.equal(result.upgrade.unavailable.blocked,true,'Insufficient-energy state not visible');
  assert.equal(result.upgrade.unavailable.status,'+9⚡','Missing energy must show exact shortfall');
  assert(result.upgrade.unavailable.next.includes(String(result.upgrade.beforeLevel+1)),'Next level hidden');
  assert(result.upgrade.unavailable.label.includes('9'),'Accessible shortage label is missing');
  assert.equal(result.upgrade.available.ready,true,'Affordable upgrade not highlighted');
  assert.equal(result.upgrade.available.status,'✓','Available upgrade lacks visible ready mark');
  assert(result.upgrade.available.label.includes('доступно'),'Affordable aria label missing');
  assert.equal(result.upgrade.purchased.level,result.upgrade.beforeLevel+1,'Unit upgrade did not apply');
  assert.equal(result.upgrade.purchased.energy,1,'Unit upgrade energy debit changed');
  assert(result.upgrade.purchased.next.includes(String(result.upgrade.beforeLevel+2)),
    'Next-level indicator did not advance after purchase');
  assert(result.upgrade.cardRects.length===3,'Lost defender upgrade buttons');
  for(const rect of result.upgrade.cardRects){
    assert(rect.width>25&&rect.left>=-4&&rect.right<=result.width+4,
      'Upgrade button outside viewport: '+JSON.stringify(rect));
    assert(rect.metaScroll<=rect.metaWidth+3,
      'Upgrade hint overflows compact card: '+JSON.stringify(rect));
  }
  assert(result.pulse,'Pulse action failed');
  assert.equal(result.speed,3,'RMB boost does not select 3x');
  assert.equal(result.ended,1,'RMB boost stuck');
  assert.equal(result.saveVersion,21,'Save version changed');
  assert(result.skill.width>10&&result.skill.left>=-3&&result.skill.right<=result.width+3,
    'Impulse offscreen: '+JSON.stringify(result.skill));
  assert(result.scrollWidth<=result.width+6,'Horizontal overflow: '+JSON.stringify(result));
  await page.screenshot({path:'screenshots/'+profile.name+'.png',fullPage:true});
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__,null,{timeout:25000});
  const saved=await page.evaluate(()=>({shards:window.__ENDLESS_DEFENDERS__.save.shards,version:window.__ENDLESS_DEFENDERS__.save.version}));
  assert.equal(saved.shards,1234,'Reload lost currency');
  assert.equal(saved.version,21,'Reload changed schema');
  assert.deepEqual(errors,[],'Browser JS errors');
  console.log('PASS '+profile.name+' '+JSON.stringify({viewport:profile.width+'x'+profile.height,save:saved,button:result.skill,canvas:result.canvas}));
 }finally{await context.close();await browser.close();}
}
(async()=>{
 require('node:fs').mkdirSync('screenshots',{recursive:true});
 for(const p of profiles)await smoke(p);
 console.log(profiles.length+' browser smoke scenarios passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
