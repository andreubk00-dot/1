'use strict';
// Deterministic SDK contract tests for the Yandex-only archive.
// Run with: node tests/yandex-ads.test.cjs
const fs=require('node:fs');
const assert=require('node:assert/strict');
const src=fs.readFileSync(require('node:path').join(__dirname,'..','index.html'),'utf8');
function section(a,b){const i=src.indexOf(a),j=src.indexOf(b,i);assert(i>=0&&j>i,a);return src.slice(i,j);}
const BALANCE={ads:{doubleRewardDailyLimit:3,reviveCorePct:.62,reviveEnergy:45,reviveCharge:50,fullscreenCooldownMs:240000}};
const now=()=>1000000000;
const document={hidden:false},navigator={language:'ru'},window={ED_YANDEX_BUILD:true};
const $elements=new Map();
function $(id){if(!$elements.has(id)){const classes=new Set();$elements.set(id,{textContent:'',disabled:false,classList:{add:(x)=>classes.add(x),remove:(x)=>classes.delete(x),contains:(x)=>classes.has(x)}});}return $elements.get(id);}
const Bridge=new Function('window','navigator','document','BALANCE','now',section('  class YandexBridge {','\n\n  /*')+'\nreturn YandexBridge;')(window,navigator,document,BALANCE,now);
let scheduledFrames=0;
const Game=new Function('BALANCE','$','fmt','now','document','requestAnimationFrame','return ('+section('  class Game {',"\n\n  window.addEventListener('DOMContentLoaded'").trim()+')')(BALANCE,$,String,now,document,()=>++scheduledFrames);
function fixture(){
  const g=Object.create(Game.prototype);
  g.inRun=false;g.paused=false;g.pauseOverlay=false;g.externalPauseWasPaused=false;
  g.save={shards:1000,gems:20,quests:{doubleAds:0},analytics:{events:{}},lastFullscreenAt:0,noInterstitial:false};
  g.run={wave:10,reached:10,earnedShards:100,earnedGems:0,revived:false,resultDoubled:false,maxCore:100,core:0,energy:10,commanderCharge:0,commanderHeat:90,commanderOverheated:true,enemies:[],projectiles:[]};
  g.t={noAd:'Ad unavailable'};g.lang='ru';g.persist=()=>{};g.renderHome=()=>{};
  g.toast=()=>{};g.showScreen=()=>{};g.track=()=>{};g.audio={startCombatMusic:()=>{}};g.waveEnemyCount=()=>5;g.handleExternalPause=()=>{};
  const bridge=g.bridge=new Bridge(g);let callbacks,requestCount=0;
  bridge.ysdk={adv:{showRewardedVideo:({callbacks:c})=>{requestCount++;callbacks=c;},showFullscreenAdv:({callbacks:c})=>{callbacks=c;}}};
  return {g,bridge,callbacks:()=>callbacks,requests:()=>requestCount};
}
const cases=[];
async function test(label,fn){await fn();cases.push(label);console.log('PASS',label);}
(async()=>{
  await test('No SDK: no free reward',async()=>{
    const f=fixture();f.bridge.ysdk=null;let n=0;assert.equal(await f.bridge.rewardAd(()=>n++),false);assert.equal(n,0);
  });
  await test('Closed ad: no double payout',async()=>{
    const f=fixture();const pending=f.g.doubleResult();const concurrent=f.g.doubleResult();assert.equal(f.requests(),1);f.callbacks().onClose(true);await Promise.all([pending,concurrent]);assert.equal(f.g.save.shards,1000);assert.equal(f.g.save.quests.doubleAds,0);
  });
  await test('Rewarded ad: one payout for duplicate callbacks',async()=>{
    const f=fixture();const pending=f.g.doubleResult();f.callbacks().onRewarded();f.callbacks().onRewarded();f.callbacks().onClose(true);f.callbacks().onClose(true);await pending;assert.equal(f.g.save.shards,1100);assert.equal(f.g.save.quests.doubleAds,1);
  });
  await test('onError after reward does not credit',async()=>{
    const f=fixture();const pending=f.g.doubleResult();f.callbacks().onRewarded();f.callbacks().onError('network');f.callbacks().onClose(true);await pending;assert.equal(f.g.save.shards,1000);
  });
  await test('Revive requires verified reward',async()=>{
    const f=fixture();const pending=f.g.reviveRun();f.callbacks().onClose(true);await pending;assert.equal(f.g.inRun,false);assert.equal(f.g.save.shards,1000);
  });
  await test('Successful revive does not duplicate run rewards',async()=>{
    const f=fixture();const pending=f.g.reviveRun();f.callbacks().onRewarded();f.callbacks().onClose(true);await pending;assert.equal(f.g.run.revived,true);assert.equal(f.g.save.shards,900);assert.equal(f.g.run.energy,55);
  });
  await test('Interstitial needs confirmed wasShown',async()=>{
    const f=fixture();let p=f.bridge.fullscreen();f.callbacks().onOpen();f.callbacks().onClose(false);assert.equal(await p,false);assert.equal(f.g.save.lastFullscreenAt,0);
    p=f.bridge.fullscreen();f.callbacks().onClose(true);assert.equal(await p,true);assert.equal(f.g.save.lastFullscreenAt,1000000000);
  });
  await test('Manually ended run never offers a rewarded revive',async()=>{
    const f=fixture();f.g.run.manualEnd=true;
    await f.g.reviveRun();
    assert.equal(f.requests(),0);
    assert.equal(f.g.run.revived,false);
  });
  await test('Rewarded revive requires a real qualifying wave',async()=>{
    const f=fixture();f.g.run.reached=1;
    await f.g.reviveRun();
    assert.equal(f.requests(),0);
  });
  await test('Double reward requires actual wave and earned shards',async()=>{
    const f=fixture();f.g.run.reached=1;
    await f.g.doubleResult();assert.equal(f.requests(),0);
    f.g.run.reached=10;f.g.run.earnedShards=0;
    await f.g.doubleResult();assert.equal(f.requests(),0);
    assert.equal(f.g.save.shards,1000);
  });
  await test('Double reward blocks subsequent revive on the same result',async()=>{
    const f=fixture(),pending=f.g.doubleResult();
    f.callbacks().onRewarded();f.callbacks().onClose(true);await pending;
    await f.g.reviveRun();
    assert.equal(f.requests(),1);
    assert.equal(f.g.run.revived,false);
    assert.equal(f.g.run.resultDoubled,true);
  });
  await test('Fullscreen onOpen without verified showing never consumes session quota',async()=>{
    const f=fixture();f.g.sessionInterstitials=0;
    const p=f.bridge.fullscreen();
    f.callbacks().onOpen();f.callbacks().onClose(false);
    assert.equal(await p,false);
    assert.equal(f.g.sessionInterstitials,0);
    assert.equal(f.g.save.lastFullscreenAt,0);
  });
  await test('Only confirmed fullscreen views increment session quota once',async()=>{
    const f=fixture();f.g.sessionInterstitials=0;
    const p=f.bridge.fullscreen();
    f.callbacks().onOpen();f.callbacks().onOpen();
    f.callbacks().onClose(true);f.callbacks().onClose(true);
    assert.equal(await p,true);
    assert.equal(f.g.sessionInterstitials,1);
    assert.equal(f.g.save.lastFullscreenAt,1000000000);
  });
  await test('Rejected rewarded ad leaves both result buttons available',async()=>{
    const f=fixture(),p=f.g.doubleResult();
    assert.equal($('doubleRewardBtn').disabled,true);
    f.callbacks().onError('no-fill');await p;
    assert.equal(f.g.resultAdBusy,false);
    assert.equal($('doubleRewardBtn').disabled,false);
    assert.equal($('reviveBtn').disabled,false);
    assert.equal(f.g.save.shards,1000);
  });
  await test('Synced v1.8.24 UI and save version are present in the Yandex package',async()=>{
    assert(src.includes('<title>Бесконечные защитники — Яндекс Игры v1.8.24</title>'));
    assert(src.includes('window.ED_YANDEX_BUILD=true;'));
    assert(src.includes('<script src="/sdk.js"></script>'));
    assert(src.includes('out.version=21'),'Save migration to schema 21 missing');
    assert(src.includes('id="collectionSquadSummary"'),'Selected squad summary missing');
    assert(src.includes('unit-upgrade-meta'),'Battle upgrade energy indicator missing');
    assert(src.includes('.boss-hud:not(.hidden) ~ .boss-objective{top:140px}'),
      'Narrow-phone boss help clearance missing');
    assert.equal(typeof Game.prototype.squadSummaryData,'function');
    assert.equal(typeof Game.prototype.activeSynergy,'function');
    assert.equal(typeof Game.prototype.unitUpgradeCost,'function');
    assert(!src.includes('onrender.com/'),'Standalone promo link must not leak to Yandex');
  });
  await test('No ad API cannot claim a revival or doubled reward',async()=>{
    const f=fixture();f.bridge.ysdk=null;
    await f.g.reviveRun();await f.g.doubleResult();
    assert.equal(f.requests(),0);
    assert.equal(f.g.save.shards,1000);
    assert.equal(f.g.run.revived,false);
    assert.equal(f.g.run.resultDoubled,false);
    assert.equal(f.g.save.quests.doubleAds,0);
  });
  await test('SDK reward controls are hidden until actual rewarded ads exist',async()=>{
    const a="const adAvailable=!!this.bridge.ysdk?.adv?.showRewardedVideo;";
    assert(src.includes(a));
    assert(src.includes("classList.toggle('hidden',!canDouble||!adAvailable)"));
    assert(src.includes("classList.toggle('hidden',!canRevive||!adAvailable)"));
    assert(src.includes("if(!this.ysdk?.adv?.showRewardedVideo)return false;"),
      'Yandex builds may not grant phantom rewards');
  });
  await test('Consumable purchase must persist to cloud before SDK consumption',async()=>{
    const {g,bridge}=fixture();let saved=0,consumed=[],persisted=0;
    g.persist=()=>{persisted++;};
    bridge.saveCloud=async()=>{saved++;return true;};
    bridge.consume=async token=>{consumed.push(token);return true;};
    await g.applyPurchase({productID:'crystals_80',purchaseToken:'purchase-1'});
    assert.equal(g.save.gems,100);assert.equal(g.save.shards,1000);
    assert.equal(g.save.purchases['purchase-1'],true);
    assert.equal(saved,1);assert.deepEqual(consumed,['purchase-1']);
    assert.equal(persisted,1);
    await g.applyPurchase({productID:'crystals_80',purchaseToken:'purchase-1'});
    assert.equal(g.save.gems,100,'Duplicate callback awarded 80 crystals twice');
    assert.equal(persisted,1,'Duplicate callback persisted currency twice');
  });
  await test('Failed cloud save preserves purchase token for a safe retry',async()=>{
    const {g,bridge}=fixture();let cloudReady=false,consumed=[],local=0;
    g.persist=()=>{local++;};
    bridge.saveCloud=async()=>cloudReady;
    bridge.consume=async token=>{consumed.push(token);return true;};
    const p={productID:'supporter_pack',purchaseToken:'purchase-2'};
    await g.applyPurchase(p);
    assert.equal(g.save.gems,200);assert.equal(g.save.shards,1500);
    assert.equal(g.save.purchases['purchase-2'],true);
    assert.equal(local,1);
    assert.deepEqual(consumed,[],'Cloud-save failure consumed purchase irreversibly');
    cloudReady=true;
    await g.applyPurchase(p);
    assert.equal(g.save.gems,200);assert.equal(g.save.shards,1500);
    assert.deepEqual(consumed,['purchase-2'],'Successful retry did not consume pending purchase');
    assert.equal(local,1,'Receipt recovery paid out twice');
  });
  await test('Duplicated asynchronous purchase callbacks are serialized',async()=>{
    const {g,bridge}=fixture();let ack,received=0;
    bridge.saveCloud=()=>new Promise(resolve=>{ack=resolve;});
    bridge.consume=async()=>{received++;return true;};
    const purchase={productID:'crystals_250',purchaseToken:'purchase-3'};
    const first=g.applyPurchase(purchase),second=g.applyPurchase(purchase);
    assert.equal(g.save.gems,270,'Concurrent callbacks awarded currency twice');
    assert.equal(g._purchaseProcessing.size,1);
    await second;ack(true);await first;
    assert.equal(received,1,'Concurrent SDK callback consumed purchase twice');
    assert.equal(g._purchaseProcessing.size,0);
  });
  await test('Invalid, unrecognized or tokenless products never award currency',async()=>{
    const {g,bridge}=fixture();let calls=0;
    bridge.saveCloud=async()=>{calls++;return true;};
    await g.applyPurchase({productID:'crystals_250',purchaseToken:''});
    await g.applyPurchase({productID:'crystals_250'});
    await g.applyPurchase({productID:'unknown_sku',purchaseToken:'purchase-4'});
    assert.equal(g.save.gems,20);assert.equal(g.save.shards,1000);
    assert.equal(calls,0,'Unverified purchase reached cloud');
  });
  await test('Permanent no-interstitial purchase is never consumed',async()=>{
    const {g,bridge}=fixture();let consumed=0;
    bridge.saveCloud=async()=>true;bridge.consume=async()=>{consumed++;return true;};
    const purchase={productID:'no_interstitial',purchaseToken:'purchase-5'};
    await g.applyPurchase(purchase);await g.applyPurchase(purchase);
    assert.equal(g.save.noInterstitial,true);
    assert.equal(g.save.purchases['purchase-5'],true);
    assert.equal(consumed,0,'Permanent purchase must remain queryable');
  });
  await test('A failed pending purchase cannot block later receipts or startup',async()=>{
    const {g,bridge}=fixture();const seen=[];
    bridge.pendingPurchases=async()=>[
      {productID:'crystals_80',purchaseToken:'bad-receipt'},
      {productID:'crystals_250',purchaseToken:'good-receipt'}
    ];
    g.applyPurchase=async p=>{
      seen.push(p.purchaseToken);
      if(p.purchaseToken==='bad-receipt')throw Error('temporary cloud failure');
    };
    const warn=console.warn;console.warn=()=>{};
    try{await g.processPendingPurchases();}finally{console.warn=warn;}
    assert.deepEqual(seen,['bad-receipt','good-receipt']);
  });
  await test('Paused and background gameplay stops heavy canvas draws',async()=>{
    const {g}=fixture();let draws=0,steps=0,samples=0;
    g.lastFrame=100;g.paused=false;g.externalPause=false;
    g.draw=()=>{draws++;};g.stepCombat=()=>{steps++;};g.samplePerformance=()=>{samples++;};
    const first=scheduledFrames;
    const frame=(ts,drawCount)=>{g.loop(ts);assert.equal(draws,drawCount);};
    frame(116,1);
    document.hidden=true;frame(132,1);
    document.hidden=false;g.paused=true;frame(148,1);
    g.paused=false;g.externalPause=true;frame(164,1);
    g.externalPause=false;$('battleScreen').classList.add('hidden');frame(180,1);
    $('battleScreen').classList.remove('hidden');frame(196,2);
    assert.equal(steps,6);assert.equal(samples,6);
    assert.equal(scheduledFrames-first,6,'Animation loop scheduling changed');
  });
  await test('Unacknowledged first-session coach survives reopening the game',async()=>{
    const {g}=fixture();let saved=0;
    g.save.coachSeen={};g.persist=()=>{saved++;};
    g.coachData=()=>({icon:'◎',kicker:'Test',title:'Resources',text:'Use shards',tip:'Tip'});
    assert.equal(g.showCoach('resources'),true);
    assert.equal(g.save.coachSeen.resources,undefined,'Opening already suppressed the tip');
    assert.equal(saved,0);
    assert.equal(g.showCoach('fragments'),false,'Pending tip was replaced before acknowledgement');
    // Recreate the Game instance with only progress that was actually saved.
    const reopened=fixture().g;
    reopened.save.coachSeen={...g.save.coachSeen};
    reopened.coachData=g.coachData;
    let acks=0;reopened.persist=()=>{acks++;};
    assert.equal(reopened.showCoach('resources'),true);
    reopened.closeCoach();
    assert.equal(reopened.save.coachSeen.resources,true);
    assert.equal(acks,1);
    reopened.closeCoach();assert.equal(acks,1);
    assert.equal(reopened.showCoach('resources'),false);
  });
  await test('Cosmetic critical glint obeys mobile FX budget',async()=>{
    const {g}=fixture();g.run.effects=[];g.save.lowFx=false;g.autoLowFx=false;
    g.spawnCritGlint(320,240);assert.equal(g.run.effects.filter(f=>f.type==='crit').length,1);
    for(let i=0;i<30;i++)g.spawnCritGlint(320,240);
    assert.equal(g.run.effects.filter(f=>f.type==='crit').length,5);
    g.run.effects=[];g.save.lowFx=true;g.spawnCritGlint(320,240);
    assert.equal(g.run.effects.length,0);
    g.save.lowFx=false;g.run.enemies=new Array(72).fill(null);g.spawnCritGlint(320,240);
    assert.equal(g.run.effects.length,0);
    assert(src.includes("if(p.crit){this.spawnRing(e.x,e.y,'#ffe27d',5,32,.2);this.spawnCritGlint(e.x,e.y);}"));
  });
  await test('Laboratory funding has accessible progress and no altered prices',async()=>{
    assert(src.includes('data-lab-funding="'), 'Funding meter is missing');
    assert(src.includes('role="progressbar"'), 'Progress meter needs a semantic role');
    assert(src.includes('aria-valuenow='), 'Progress meter must expose shard count');
    assert(src.includes("cost=this.labUpgradeCost(k,level)"), 'Laboratory must use the existing price formula');
    assert(src.includes('На следующий уровень')&&src.includes('Next level'), 'Progress description needs both languages');
    assert(src.includes("max?'':"), 'Maxed upgrades must not show a funding goal');
  });
  await test('Hidden rewarded placements do not inflate Yandex ad offer metrics',async()=>{
    const {g}=fixture();const offers=[];
    g.track=(name,meta)=>{if(name==='reward_ad_offer')offers.push(meta);};
    g.recordVisibleRewardOffers(true,true,false,10);
    assert.deepEqual(offers,[],'No SDK should create zero offers');
    g.recordVisibleRewardOffers(true,false,true,12);
    assert.deepEqual(offers,[{placement:'revive',wave:12}]);
    g.recordVisibleRewardOffers(false,true,true,15);
    assert.deepEqual(offers,[{placement:'revive',wave:12},{placement:'double',wave:15}]);
    g.recordVisibleRewardOffers(false,false,true,20);
    assert.equal(offers.length,2,'Ineligible buttons were counted as offers');
    assert(src.includes('this.recordVisibleRewardOffers(canRevive,canDouble,adAvailable,reached);'));
    assert(src.includes("classList.toggle('hidden',!canDouble||!adAvailable)"));
  });
  await test('Ads and hidden tabs do not inflate playtime; next-day return is recorded',async()=>{
    const doc=document,oldHidden=doc.hidden;
    let clock=1000000,day='2026-10-08',resumed=0;
    const TimedGame=new Function('BALANCE','$','fmt','now','dayKey','document','requestAnimationFrame',
      'return ('+section('  class Game {',"\n\n  window.addEventListener('DOMContentLoaded'").trim()+')')(
      BALANCE,$,String,()=>clock,()=>day,doc,()=>0);
    const g=Object.create(TimedGame.prototype);
    g.save={analytics:{totalPlayMs:0,firstSessionDay:day,playDays:[day],events:{},retention:{d1:false,d3:false,d7:false}}};
    g.sessionActiveAt=clock-10000;g.inRun=true;g.paused=false;g.pauseOverlay=false;
    g.externalPause=false;g.externalPauseWasPaused=false;g.externalPauseReasons=new Set();
    g.run={holdFire:true,aim:{x:300,y:200}};g.setRmbBoost=()=>{};g.pauseInternal=()=>{};
    g.bridge={gameplayStop:()=>{},gameplayStart:()=>{resumed++;}};g.audio={resume:()=>{}};
    g.track=name=>{const e=g.save.analytics.events;e[name]=(e[name]||0)+1;};
    try{
      g.handleExternalPause(true,'ad');
      assert.equal(g.save.analytics.totalPlayMs,10000);
      assert.equal(g.sessionActiveAt,0);
      clock+=60000;doc.hidden=true;g.handleExternalPause(true,'visibility');
      doc.hidden=false;day='2026-10-09';
      g.resumePlaytime();g.handleExternalPause(false,'visibility');
      assert.equal(g.sessionActiveAt,0);
      assert.equal(g.save.analytics.events.session_day||0,0);
      clock+=30000;g.handleExternalPause(false,'ad');
      assert.equal(g.sessionActiveAt,clock);
      assert.equal(g.save.analytics.events.session_day,1);
      assert.equal(g.save.analytics.events.retention_d1,1);
      g.resumePlaytime();assert.equal(g.save.analytics.events.session_day,1);
      clock+=2000;g.checkpointPlaytime();
      assert.equal(g.save.analytics.totalPlayMs,12000);
      assert.equal(resumed,1);
    }finally{doc.hidden=oldHidden;}
  });
  await test('Result screens and ads do not double-count final run depth',async()=>{
    const {g}=fixture();g.track=Game.prototype.track;
    g.save.analytics={events:{},waves:{},recent:[]};g.save.runs=1;g.save.sound=false;
    g.canShowInterstitial=()=>false;g.audio.startMenuMusic=()=>{};g.showScreen=()=>{};
    g.run.reached=5;g.run.completed=4;g.run.startedAt=999990000;g.run.firstRun=true;
    g.track('boss_kill',{wave:5});g.track('reward_ad_attempt',{wave:5});
    g.track('run_result',g.runOutcomeMeta(g.run));
    g.run.revived=true;g.run.reached=10;g.run.completed=9;g.run.wave=10;
    g.track('run_result',g.runOutcomeMeta(g.run));
    assert.deepEqual(g.save.analytics.waves,{});
    await g.leaveResult();
    assert.equal(g.save.analytics.events.run_finish,1);
    assert.equal(g.save.analytics.events.run_result,2);
    assert.equal(g.save.analytics.events.run_end_defeat,1);
    assert.deepEqual(g.save.analytics.waves,{'10':1});
    const outcome=g.save.analytics.recent.at(-1);
    assert.equal(outcome.meta.revived,true);assert.equal(outcome.meta.completed,9);
    assert.equal(g.analyticsSummary().runs.defeats,1);
  });
  await test('Syntax of all inline scripts',async()=>{
    const chunks=[...src.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];assert(chunks.length>=5);for(const [,attr,body] of chunks)if(!/\bsrc\s*=/.test(attr)&&body.trim())new Function(body);
  });
  console.log(cases.length+' Yandex SDK smoke tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
