'use strict';
// Reproducible long-horizon economy model; uses the live Game wave-count and BALANCE constants.
// Assumptions: every run is completed to the target depth, all kills secured, zero lab income,
// zero Rift/quest/chest/achievement bonuses, all earned currencies reserved for new defenders.
// Rewarded advertising grants ONLY another copy of base shards, max two on a modeled 24h period.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const scripts=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const win={};
const code=scripts[1].replace(
 "window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });",
 "window.__econ={Game,BALANCE,DEFENDER_CONTRACTS};");
assert(code.includes('window.__econ={Game'),'Cannot extract current game formulas');
new Function('window','document','navigator','performance',scripts[0]+'\n'+code)(win,{}, {language:'ru'},{now:()=>0});
const {Game,BALANCE,DEFENDER_CONTRACTS}=win.__econ,g=Object.create(Game.prototype);
const depth={prism:45,nova:55,ember:65,volt:105,chrono:125};
const bosses={aegis:10,leech:20,singularity:30};
function perRun(id){
 const d=depth[id],e=BALANCE.economy;let kills=0;
 for(let w=1;w<=d;w++)kills+=g.waveEnemyCount(w);
 const bonus=Math.min(e.shardDepthBonusCap,1+Math.max(0,d-e.shardDepthBonusStartWave)*e.shardDepthBonusPerWave);
 return {shards:Math.floor((d*e.runShardPerWave+Math.sqrt(kills)*e.runShardKillSqrt)*bonus),
         gems:Math.floor(d/10)+Math.floor(d/e.runGemEvery)+(d>=e.runGemWaveThreshold?1:0)};
}
function simulate(seed,adPerDay,runsPerDay){
 let state=seed>>>0,shards=0,gems=0,runs=0,ads=0;
 const random=()=>((state=(Math.imul(state,1664525)+1013904223)>>>0)/4294967296);
 for(const id of Object.keys(depth)){
  const c=DEFENDER_CONTRACTS[id],payment=perRun(id);
  let parts=0,pity=0;
  while((parts<c.parts||shards<c.shards||gems<c.gems)&&runs<1000){
   runs++;shards+=payment.shards;gems+=payment.gems;
   if((runs-1)%runsPerDay<adPerDay){shards+=payment.shards;ads++;}
   for(let w=bosses[c.source];w<=depth[id];w+=30){
    if(w<c.minWave||parts>=c.parts)continue;
    const depthBonus=Math.min(.12,Math.max(0,Math.floor((w-c.minWave)/30))*.03);
    if(pity+1>=c.pity||random()<Math.min(.60,c.chance+depthBonus)){pity=0;parts++;}else pity++;
   }
  }
  assert(runs<1000,'Contract impossible');
  shards-=c.shards;gems-=c.gems;
 }
 return {runs,ads};
}
function runSamples(ads,plays){
 const all=[];for(let i=0;i<2000;i++)all.push(simulate(i*1777+1839,ads,plays));
 all.sort((a,b)=>a.runs-b.runs);
 return {p10:all[200].runs,median:all[1000].runs,p90:all[1800].runs,min:all[0].runs,max:all.at(-1).runs};
}
assert.equal(BALANCE.ads.doubleRewardDailyLimit,2,'Daily rewarded ad cap changed');
assert.equal(Object.values(DEFENDER_CONTRACTS).reduce((s,c)=>s+c.shards,0),48000,'Contract shard sinks unexpectedly changed');
assert.equal(Object.values(DEFENDER_CONTRACTS).reduce((s,c)=>s+c.gems,0),303,'Contract gem sinks unexpectedly changed');
const normal=runSamples(0,4),withAds=runSamples(2,4),casual=runSamples(2,8);
assert(normal.median>=70&&normal.median<=100,'Free progression unexpectedly short/long: '+JSON.stringify(normal));
assert(withAds.median>=55,'2 daily reward ads trivialize progression: '+JSON.stringify(withAds));
assert(withAds.median<normal.median,'Reward advertising unexpectedly has no economic effect');
assert(casual.median>withAds.median,'More frequent reward opportunities are not helping');
console.log('PASS economy progression model '+JSON.stringify({normal,withAds,casual}));
console.log('Assumptions: all waves cleared, no other rewards/spending; NOT a prediction of player hours');
