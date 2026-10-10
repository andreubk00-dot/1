'use strict';
// In a regular browser without VK SDK, the game must load, play and never give free ad rewards.
const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict');
const scenarios=[
  {platform:'vk',port:4175,engine:chromium,width:390,height:844},
  {platform:'ok',port:4176,engine:chromium,width:390,height:844},
  {platform:'vk',port:4175,engine:webkit,width:390,height:844},
  {platform:'ok',port:4176,engine:webkit,width:390,height:844}
];
async function check(p){
  const browser=await p.engine.launch({headless:true});
  const context=await browser.newContext({viewport:{width:p.width,height:p.height},
    hasTouch:true,serviceWorkers:'block',locale:'ru-RU',reducedMotion:'reduce'});
  const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  try{
    await page.goto('http://127.0.0.1:'+p.port+'/',{waitUntil:'domcontentloaded',timeout:30000});
    await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__,null,{timeout:25000});
    await page.waitForSelector('#shell:not(.hidden)',{timeout:25000});
    assert(await page.locator('#playBtn').isVisible(),'Missing play button on '+p.platform);
    const audioResponse=await page.request.get('http://127.0.0.1:'+p.port+'/audio/menu_theme.ogg');
    assert.equal(audioResponse.status(),200,'Missing music file on '+p.platform);
    assert((await audioResponse.body()).length>10000,'Broken audio payload on '+p.platform);
    assert(!(await page.locator('#vkInviteBtn').isVisible()),'Invite should be hidden outside VK client');
    assert(!(await page.locator('#authBtn').isVisible()),'Unsupported account login must be hidden');
    const baseline=await page.evaluate(async()=>{
      const g=window.__ENDLESS_DEFENDERS__;
      let grants=0;
      const ad=await g.bridge.rewardAd(()=>{grants++;});
      const inter=await g.bridge.fullscreen();
      return {version:g.save.version,platform:window.ED_VK_PLATFORM,
        ready:g.bridge.ready,grants,ad,inter};
    });
    assert.equal(baseline.version,21,'Save schema changed');
    assert.equal(baseline.platform,p.platform);
    assert.equal(baseline.ready,false,'Social SDK should not initialize outside platform');
    assert.equal(baseline.grants,0,'Missing SDK provided free rewards');
    assert.equal(baseline.ad,false);
    assert.equal(baseline.inter,false);
    const gameplay=await page.evaluate(()=>{
      const g=window.__ENDLESS_DEFENDERS__;
      g.save.tutorialDone=true;g.audio.enabled=false;g.startRun(false);
      const started=g.inRun&&g.run?.wave===1;
      g.save.shards=4321;g.persist(true);
      return {started,canvas:!!g.canvas,saveKey:window.ED_VK_PLATFORM};
    });
    assert(gameplay.started&&gameplay.canvas,'Combat start failed for '+p.platform);
    await page.waitForTimeout(150);
    await page.reload({waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!!window.__ENDLESS_DEFENDERS__,null,{timeout:25000});
    const saved=await page.evaluate(()=>window.__ENDLESS_DEFENDERS__.save.shards);
    assert.equal(saved,4321,'Social save lost after reload');
    assert.deepEqual(errors,[],'Browser JS errors in '+p.platform+': '+errors.join(','));
    console.log('PASS '+p.platform+' '+(p.engine===webkit?'webkit':'chromium'));
  }finally{
    await context.close();await browser.close();
  }
}
(async()=>{for(const s of scenarios)await check(s);console.log('PASS all VK/OK browser smoke cases');})()
  .catch(e=>{console.error(e);process.exitCode=1;});