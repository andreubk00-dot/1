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
  assert(s.includes('new VKGamesBridge(this)'));
  assert(s.includes('class VKGamesBridge {'));
  assert(s.includes('src="./bridge.bundle.js"'));
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
window.ED_VK_BRIDGE={send:async(method,p)=>{apiCalls.push({method,p});return handler(method,p);}};
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
  await bridge.init();
  assert.equal(bridge.ready,true);
  assert.equal(apiCalls[0].method,'VKWebAppInit');
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
  assert.equal(await bridge.purchase('crystals_80'),null);
  assert.deepEqual(await bridge.pendingPurchases(),[]);
  assert.equal(await bridge.loadCloud(),null,'Unverified cloud storage must remain disabled');
  assert.equal(await bridge.saveCloud({}),false);
  assert.equal(await bridge.authorize(),false);
  console.log('PASS independent VK/OK HTML5 packages, SDK ad confirmation, safety, save separation');
})().catch(e=>{console.error(e);process.exitCode=1;});