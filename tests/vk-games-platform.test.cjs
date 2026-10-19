'use strict';
// VK and OK builds use the same gameplay but isolate saves and real SDK rewards.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const v=fs.readFileSync(path.join(ROOT,'dist','vk','index.html'),'utf8');
const o=fs.readFileSync(path.join(ROOT,'dist','ok','index.html'),'utf8');
const script=s=>[...s.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
for(const [name,s] of [['vk',v],['ok',o]]){
  assert(s.includes("window.ED_VK_PLATFORM='"+name+"'"));
  assert(s.includes('<title>Guardborn —'),'Package must use new title');
  assert(s.includes("title:'Guardborn'"),'Both languages must use Guardborn');
  assert(!s.includes('Бесконечные защитники'),'Old public title must be removed');
  assert(s.includes('new VKGamesBridge(this)'));
  assert(s.includes('class VKGamesBridge {'));
  assert(s.includes('src="./bridge.bundle.js"'));
  const media=[...new Set([...s.matchAll(/local\('([A-Za-z0-9_-]+\.ogg)'\)/g)].map(m=>m[1]))];
  assert.equal(media.length,13,'Unexpected in-game audio manifest');
  for(const filename of media){
    const item=path.join(ROOT,'dist',name,'audio',filename);
    assert(fs.statSync(item).size>0,'Game audio missing from '+name+': '+filename);
  }
  assert(s.includes('endless_defenders_'+name+'_save_v1'));
  assert(!s.includes('endless_defenders_save_v1'));
  assert(!s.includes('YaGames.init'));
  assert(!s.includes("if(window.ED_YANDEX_BUILD)return;"));
  assert(s.includes('id="vkInviteBtn"'));
  assert(s.includes('this.bridge.ready'));
  assert(!s.includes('rel="manifest"'));
  for(const m of script(s)){
    if(!/\bsrc\s*=/.test(m[1])&&m[2].trim())new Function(m[2]);
  }
  const bundle=fs.readFileSync(path.join(ROOT,'dist',name,'bridge.bundle.js'),'utf8');
  assert(bundle.length>1000,'Bundled SDK missing for '+name);
}
const gameScript=s=>script(s).map(x=>x[2]).find(x=>x.includes('  class Game {'));
const normalized=s=>s.replaceAll('endless_defenders_vk_save_v1','endless_defenders_platform_save_v1')
  .replaceAll('endless_defenders_ok_save_v1','endless_defenders_platform_save_v1');
assert.equal(normalized(gameScript(v)),normalized(gameScript(o)),
  'VK and OK gameplay code diverged beyond isolated save names');
const start=v.indexOf('  class VKGamesBridge {'),end=v.indexOf('  /*\n    AUDIO ASSET SOURCES',start);
assert(start>=0&&end>start);
let clock=1000000000;
const window={ED_VK_PLATFORM:'vk'};
const document={hidden:false};
const apiCalls=[];
let handler=async(method,p)=>({result:true});
window.ED_VK_BRIDGE={isEmbedded:()=>true,send:async(method,p)=>{apiCalls.push({method,p});return handler(method,p);}};
const VKGamesBridge=new Function('window','navigator','document','now','BALANCE','$',
  'return ('+v.slice(start,end).trim()+')')(
    window,{language:'ru'},document,()=>clock,{ads:{fullscreenCooldownMs:240000}},()=>null
  );
const game={
  inRun:true,paused:false,pauseOverlay:false,externalPauseWasPaused:true,
  save:{noInterstitial:false,lastFullscreenAt:0},
  sessionInterstitials:0,persistCount:0,
  persist(){this.persistCount++;},
  pauses:[],handleExternalPause(on,source){this.pauses.push({on,source});}
};
(async()=>{
  const bridge=new VKGamesBridge(game);
  assert.equal(await bridge.rewardAd(()=>{throw Error('free reward');}),false,'Missing SDK granted currency');
  const sdk=window.ED_VK_BRIDGE;
  window.ED_VK_BRIDGE={...sdk,isEmbedded:()=>false};
  const outside=new VKGamesBridge(game);
  await outside.init();
  assert.equal(outside.ready,false,'VK SDK must not hang on direct browser previews');
  window.ED_VK_BRIDGE=sdk;
  await bridge.init();
  assert.equal(bridge.ready,true);
  assert.equal(apiCalls[0].method,'VKWebAppInit');
  // Simulate a broken VK/OK iframe host: no VKWebAppInit answer ever arrives.
  // The game must finish initialization in local-only mode instead of hanging.
  let resolveLateInit;
  handler=()=>new Promise(resolve=>{resolveLateInit=resolve;});
  const stalled=new VKGamesBridge(game);
  stalled.initTimeoutMs=25;
  await stalled.init();
  assert.equal(stalled.ready,false,'An unresponsive host falsely enabled the SDK');
  assert.equal(await stalled.rewardAd(()=>{throw Error('unconfirmed reward');}),false,
    'Timed-out host provided a free reward');
  resolveLateInit({result:true});
  await Promise.resolve();await Promise.resolve();
  assert.equal(stalled.ready,false,'Late SDK reply enabled an unverified social session');
  handler=async()=>({result:true});
  let grants=0;
  handler=async()=>({result:false});
  assert.equal(await bridge.rewardAd(()=>grants++),false,'Unconfirmed ad rewarded');
  assert.equal(grants,0);
  handler=async()=>{throw Error('Ad unavailable');};
  assert.equal(await bridge.rewardAd(()=>grants++),false,'Rejected ad rewarded');
  assert.equal(grants,0);
  let release;
  handler=()=>new Promise(resolve=>{release=resolve;});
  const pending=bridge.rewardAd(()=>grants++);
  assert.equal(await bridge.rewardAd(()=>grants++),false,'Parallel ad calls must be blocked');
  release({result:true});
  assert.equal(await pending,true);
  assert.equal(grants,1,'Confirmed ad must grant only once');
  assert.equal(game.pauses.filter(x=>x.on===true&&x.source==='ad').length,3);
  assert.equal(game.pauses.filter(x=>x.on===false&&x.source==='ad').length,3);
  assert.equal(game.externalPauseWasPaused,false,'Successful revive must be able to resume');
  handler=async()=>({result:false});
  assert.equal(await bridge.fullscreen(),false);
  assert.equal(game.save.lastFullscreenAt,0,'Failed interstitial advanced cooldown');
  handler=async()=>({result:true});
  assert.equal(await bridge.fullscreen(),true);
  assert.equal(game.save.lastFullscreenAt,clock);
  assert.equal(game.sessionInterstitials,1);
  assert.equal(game.persistCount,1);
  assert.equal(await bridge.fullscreen(),false,'Interstitial cooldown not respected');
  // An unresponsive SDK ad request must finish locally, resume gameplay,
  // not update cooldowns and never grant reward on a late SDK success.
  const timeoutGame={
    ...game,
    save:{noInterstitial:false,lastFullscreenAt:0},
    pauses:[],sessionInterstitials:0,persistCount:0,
    handleExternalPause(on,source){this.pauses.push({on,source});},
    persist(){this.persistCount++;}
  };
  const timedBridge=new VKGamesBridge(timeoutGame);
  handler=async()=>({result:true});
  await timedBridge.init();
  assert.equal(timedBridge.ready,true,'Timed bridge did not connect for ad test');
  timedBridge.adTimeoutMs=25;
  const late=[];
  handler=()=>new Promise(resolve=>late.push(resolve));
  let lateRewards=0;
  assert.equal(await timedBridge.rewardAd(()=>lateRewards++),false,
    'An unresponsive rewarded ad cannot claim a reward');
  assert.equal(lateRewards,0,'Timed-out ad granted currency');
  assert.equal(timedBridge.adInProgress,false,'Timed-out reward kept the ad lock');
  assert.deepEqual(timeoutGame.pauses.slice(-2),[
    {on:true,source:'ad'},{on:false,source:'ad'}
  ],'Reward timeout did not resume gameplay');
  assert.equal(await timedBridge.fullscreen(),false,
    'Unresponsive interstitial must return false');
  assert.equal(timedBridge.adInProgress,false,'Timed-out interstitial kept the ad lock');
  assert.equal(timeoutGame.save.lastFullscreenAt,0,
    'Timed-out interstitial advanced cooldown');
  assert.equal(timeoutGame.persistCount,0,
    'Timed-out interstitial mutated saved progress');
  assert.equal(late.length,2,'Both ad formats must reach the bounded SDK request');
  for(const resolve of late)resolve({result:true});
  await Promise.resolve();await Promise.resolve();
  assert.equal(lateRewards,0,'Late SDK result granted currency after timeout');
  assert.equal(timeoutGame.sessionInterstitials,0,
    'Late SDK result counted an interstitial after timeout');
  handler=async()=>({result:true});
  assert.equal(await timedBridge.rewardAd(()=>lateRewards++),true,
    'SDK recovery cannot show ads after a timeout');
  assert.equal(lateRewards,1,'Recovered confirmed ad did not reward exactly once');
  assert.equal(timeoutGame.pauses.filter(x=>x.on).length,
    timeoutGame.pauses.filter(x=>!x.on).length,
    'SDK timeouts left the game stuck in an advertising pause');
  assert.equal(await bridge.purchase('crystals_80'),null);
  assert.deepEqual(await bridge.pendingPurchases(),[]);
  assert.equal(await bridge.loadCloud(),null,'Unverified cloud storage must remain disabled');
  assert.equal(await bridge.saveCloud({}),false);
  assert.equal(await bridge.authorize(),false);
  console.log('PASS independent VK/OK HTML5 packages, SDK ad confirmation, safety, save separation');
})().catch(e=>{console.error(e);process.exitCode=1;});