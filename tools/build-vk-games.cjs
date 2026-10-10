'use strict';
// Build two independent VK Games HTML5 packages from the tested mobile baseline.
// Prerequisites: npm install --no-save --no-package-lock esbuild@0.25.12 @vkontakte/vk-bridge@2.15.0
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const esbuild=require('esbuild');
const ROOT=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(ROOT,'iphone','index.html'),'utf8');
const audioSource=path.join(ROOT,'iphone','audio');
const audioFiles=[...new Set([...source.matchAll(/local\('([A-Za-z0-9_-]+\.ogg)'\)/g)].map(m=>m[1]))];
assert.equal(audioFiles.length,13,'Unexpected game soundtrack or SFX manifest');
for(const name of audioFiles)
  assert(fs.statSync(path.join(audioSource,name)).size>0,'Missing audio sample '+name);
const bridgeClass="  class VKGamesBridge {\n    constructor(game) {\n      this.game=game;this.api=null;this.lang=(navigator.language||'ru').slice(0,2);\n      this.ready=false;this.adInProgress=false;this.gameplayActive=false;\n      this.platform=window.ED_VK_PLATFORM||'vk';\n    }\n    async init() {\n      const api=window.ED_VK_BRIDGE;\n      if(!api?.send||(typeof api.isEmbedded==='function'&&!api.isEmbedded()))return this;\n      try {\n        await api.send('VKWebAppInit');\n        this.api=api;this.ready=true;\n      } catch(e) { console.warn('VK Games SDK init unavailable',e); }\n      return this;\n    }\n    loadingReady() {\n      const btn=$('vkInviteBtn');\n      if(!btn)return;\n      btn.hidden=!this.ready;\n      if(this.ready)btn.onclick=async()=>{\n        try { await this.api.send('VKWebAppShowInviteBox'); }\n        catch(e) { console.warn('Invite unavailable on this platform',e); }\n      };\n    }\n    gameplayStart() { this.gameplayActive=!!(this.game.inRun&&!this.game.paused); }\n    gameplayStop() { this.gameplayActive=false; }\n    isAuthorized() { return false; }\n    async authorize() { return false; }\n    // VK Storage stores only small values. The v21 save can exceed that limit.\n    // Keep the full save local until verified account sync is implemented.\n    async loadCloud() { return null; }\n    async saveCloud() { return false; }\n    async rewardAd(onReward) {\n      // No SDK or failed advertising call must NEVER grant game currency.\n      if(!this.ready||!this.api?.send||this.adInProgress)return false;\n      this.adInProgress=true;\n      this.game.handleExternalPause(true,'ad');this.gameplayStop();\n      try {\n        const ad=await this.api.send('VKWebAppShowNativeAds',{ad_format:'reward'});\n        if(ad?.result!==true)return false;\n        try {\n          onReward?.();\n          if(this.game.inRun&&!this.game.paused&&!this.game.pauseOverlay)\n            this.game.externalPauseWasPaused=false;\n          return true;\n        } catch(e) { console.error('VK reward handler failed',e);return false; }\n      } catch(e) { console.warn('VK rewarded ad unavailable',e);return false; }\n      finally {\n        this.adInProgress=false;\n        this.game.handleExternalPause(false,'ad');\n      }\n    }\n    async fullscreen() {\n      if(!this.ready||!this.api?.send||this.adInProgress)return false;\n      const save=this.game.save,cfg=BALANCE.ads||{};\n      if(save.noInterstitial||now()-save.lastFullscreenAt<(cfg.fullscreenCooldownMs||240000))return false;\n      this.adInProgress=true;\n      this.game.handleExternalPause(true,'ad');this.gameplayStop();\n      try {\n        const result=await this.api.send('VKWebAppShowNativeAds',{ad_format:'interstitial'});\n        if(result?.result!==true)return false;\n        save.lastFullscreenAt=now();\n        this.game.sessionInterstitials=(this.game.sessionInterstitials||0)+1;\n        this.game.persist();\n        return true;\n      } catch(e) { console.warn('VK interstitial unavailable',e);return false; }\n      finally {\n        this.adInProgress=false;\n        this.game.handleExternalPause(false,'ad');\n      }\n    }\n    // No verified social leaderboard or purchase receipts yet; fail closed.\n    async submitScore() { return false; }\n    async getCatalog() { return []; }\n    async purchase() { return null; }\n    async pendingPurchases() { return []; }\n    async consume() { return false; }\n  }\n";
function replaceOnce(haystack,find,replacement){
  assert.equal(haystack.split(find).length,2,'Expected unique build anchor: '+find.slice(0,85));
  return haystack.replace(find,replacement);
}
const start=source.indexOf('  class YandexBridge {');
const end=source.indexOf('  /*\n    AUDIO ASSET SOURCES',start);
assert(start>=0&&end>start,'Cannot extract baseline bridge');
function build(platform){
  assert(['vk','ok'].includes(platform));
  const name=platform==='vk'?'ВКонтакте':'Одноклассники';
  let html=source.slice(0,start)+bridgeClass+'\n'+source.slice(end);
  html=replaceOnce(html,'new YandexBridge(this)','new VKGamesBridge(this)');
  html=replaceOnce(html,'<head>','<head>\n  <script defer src="./bridge.bundle.js"></script>');
  html=html.replace(/<title>[^<]+<\/title>/,
    '<title>Guardborn — '+name+' v1.8.24</title>');
  html=replaceOnce(html,'  <script>\nwindow.ED_BALANCE',
    "  <script>window.ED_VK_GAMES_BUILD=true;window.ED_VK_PLATFORM='"+platform+"';</script>\n  <script>\nwindow.ED_BALANCE");
  html=replaceOnce(html,'if(window.ED_YANDEX_BUILD)return;',
    'if(window.ED_VK_GAMES_BUILD)return;');
  html=html.replaceAll('endless_defenders_save_v1',
    'endless_defenders_'+platform+'_save_v1');
  html=replaceOnce(html,'<link rel="manifest" href="./manifest.webmanifest" />','');
  html=replaceOnce(html,'<link rel="apple-touch-icon" href="./icon-192.png" />','');
  // These packages are embedded social games, not standalone PWA installs.
  html=replaceOnce(html,'</head>',
    '<style>.platform-crosslink,#authBtn,#installAppBtn{display:none!important}</style>\n</head>');
  html=replaceOnce(html,
    '<button class="secondary-btn" id="dailyBtn">',
    '<button class="secondary-btn" id="vkInviteBtn" type="button" hidden>👥 Пригласить друзей</button>\n              <button class="secondary-btn" id="dailyBtn">');
  // Suppress rewarded-offer actions when the real social SDK is not connected.
  const adButtons="$('doubleRewardBtn').disabled=false;$('doubleRewardBtn').classList.toggle('hidden',!canDouble);$('reviveBtn').classList.toggle('hidden',!canRevive);";
  const socialAdButtons="$('doubleRewardBtn').disabled=!this.bridge.ready;$('doubleRewardBtn').classList.toggle('hidden',!canDouble||!this.bridge.ready);$('reviveBtn').classList.toggle('hidden',!canRevive||!this.bridge.ready);";
  html=replaceOnce(html,adButtons,socialAdButtons);
  assert(!html.includes('new YandexBridge(')&&!html.includes('YaGames.init'));
  const dir=path.join(ROOT,'dist',platform);
  fs.mkdirSync(dir,{recursive:true});
  fs.writeFileSync(path.join(dir,'index.html'),html);
  const audioOut=path.join(dir,'audio');
  fs.mkdirSync(audioOut,{recursive:true});
  for(const name of audioFiles)
    fs.copyFileSync(path.join(audioSource,name),path.join(audioOut,name));
  return dir;
}
const dirs=['vk','ok'].map(build);
esbuild.buildSync({
  entryPoints:[path.join(__dirname,'vk-bridge-entry.js')],
  outfile:path.join(dirs[0],'bridge.bundle.js'),
  bundle:true,format:'iife',platform:'browser',target:'es2020',minify:true,logLevel:'warning'
});
fs.copyFileSync(path.join(dirs[0],'bridge.bundle.js'),path.join(dirs[1],'bridge.bundle.js'));
for(const d of dirs){
  const html=fs.readFileSync(path.join(d,'index.html'),'utf8');
  assert(html.includes('VKWebAppShowNativeAds')&&html.includes('VKWebAppInit'));
  assert.equal(fs.readdirSync(path.join(d,'audio')).filter(f=>f.endsWith('.ogg')).length,
    audioFiles.length,'Audio not included in '+d);
  console.log('Built '+path.relative(ROOT,d)+' — '+html.length+' HTML chars');
}
