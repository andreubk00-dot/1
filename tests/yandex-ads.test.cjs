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
function $(id){if(!$elements.has(id)){const classes=new Set();$elements.set(id,{textContent:'',disabled:false,classList:{add:(x)=>classes.add(x),remove:(x)=>classes.delete(x)}});}return $elements.get(id);}
const Bridge=new Function('window','navigator','document','BALANCE','now',section('  class YandexBridge {','\n\n  /*')+'\nreturn YandexBridge;')(window,navigator,document,BALANCE,now);
const Game=new Function('BALANCE','$','fmt','now','return ('+section('  class Game {',"\n\n  window.addEventListener('DOMContentLoaded'").trim()+')')(BALANCE,$,String,now);
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
  await test('Syntax of all inline scripts',async()=>{
    const chunks=[...src.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];assert(chunks.length>=5);for(const [,attr,body] of chunks)if(!/\bsrc\s*=/.test(attr)&&body.trim())new Function(body);
  });
  console.log(cases.length+' Yandex SDK smoke tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
