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
  await test('Syntax of all inline scripts',async()=>{
    const chunks=[...src.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];assert(chunks.length>=5);for(const [,attr,body] of chunks)if(!/\bsrc\s*=/.test(attr)&&body.trim())new Function(body);
  });
  console.log(cases.length+' Yandex SDK smoke tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
