'use strict';
// Failure/retry stress MODEL: boss gates and exact Game.rollDefenderFragment,
// Game.unlockDefender and Game.buyLab are real. Wave-depth schedules are
// HYPOTHETICAL, not measured player progression or actual Game.update combat.
// Headless Game.update combat is independently guarded in combat-pacing-v1824.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const read=dir=>fs.readFileSync(path.join(__dirname,'..',dir,'index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
const a=scripts(read('pc')),b=scripts(read('iphone'));
assert.equal(a[1],b[1],'PC and phone game logic differs');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Game extraction hook missing');
let rng=1;
const random=()=>((rng=(Math.imul(rng,1664525)+1013904223)>>>0)/4294967296);
const fakeMath=Object.create(Math);fakeMath.random=random;
const win={};
new Function('window','document','navigator','performance','Math',
 a[0]+'\n'+a[1].replace(hook,
 'window.__stress={Game,BALANCE,DEFAULT_SAVE,DEFENDER_CONTRACTS,TEXT,WEEKLY_REWARDS,SEASON_REWARDS,RETURN_REWARDS};')
)(win,{}, {language:'ru'},{now:()=>0},fakeMath);
const {Game,BALANCE,DEFAULT_SAVE,DEFENDER_CONTRACTS,TEXT,WEEKLY_REWARDS,SEASON_REWARDS,RETURN_REWARDS}=win.__stress;
const ids=['prism','nova','ember','volt','chrono'],keys=['damage','core','income','start'];
const e=BALANCE.economy,ret=BALANCE.retentionEconomy;
const targetDepth=[45,55,65,105,125];
const startDepth=[28,40,49,80,100];
// Fresh ~28 / progressed ~43 are fixed-seed combat observations;
// wave 49+ and late-game ramps here are assumptions needing telemetry.
const ramps={fast:[4,5,7,10,12],moderate:[7,8,10,14,18],slow:[12,15,18,23,30]};
const compact=[[2,2,1,1],[4,3,2,2],[6,5,3,4],[9,8,5,6],[12,10,7,8]];
const bossAt=w=>w%30===10?'aegis':w%30===20?'leech':'singularity';
function game(){
 const g=Object.create(Game.prototype);
 g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));g.lang='ru';g.t=TEXT.ru;
 g.audio=new Proxy({}, {get:()=>()=>{}});
 for(const method of ['track','toast','persist','renderHome','renderCollection','celebrateReward'])g[method]=()=>{};
 return g;
}
// A boss on the wrong wave/source must never advance fragment pity.
{
 const g=game(),s=g.save;
 g.rollDefenderFragment('aegis',30);
 g.rollDefenderFragment('leech',50);
 assert.equal(s.defenderParts.prism||0,0);
 assert.equal(s.defenderPity.prism||0,0);
 g.unlockDefender('prism');
 assert(!s.unlocked.includes('prism'),'Unqualified defender unlocked');
 // Seed 1000 starts above the 30% Prism drop chance; test miss then pity.
 rng=1000;g.rollDefenderFragment('aegis',40);
 assert.equal(s.defenderPity.prism,1,'Eligible miss did not advance pity');
 s.defenderPity.prism=2;
 g.rollDefenderFragment('aegis',40);
 assert.equal(s.defenderParts.prism,1,'Third eligible boss did not guarantee fragment');
 assert.equal(s.defenderPity.prism,0,'Fragment drop did not reset pity');
}
const lookup=Array(126);{const g=game();let kills=0,xp=0;for(let n=1;n<=125;n++){
 kills+=g.waveEnemyCount(n);
 xp+=e.seasonXpWaveBase+Math.floor(n/e.seasonXpWaveStep);
 if(n%10===0)xp+=e.bossSeasonXpBase+Math.floor(n/e.bossSeasonXpStep)*4;
 const mult=Math.min(e.shardDepthBonusCap,1+Math.max(0,n-e.shardDepthBonusStartWave)*e.shardDepthBonusPerWave);
 lookup[n]={rawShards:(n*e.runShardPerWave+Math.sqrt(kills)*e.runShardKillSqrt)*mult,
 gems:Math.floor(n/10)*e.bossGemReward+Math.floor(n/e.runGemEvery)+(n>=e.runGemWaveThreshold?1:0),xp};
}}
const expectedLabCost=compact.at(-1).reduce((sum,lv,i)=>{
 const g=game();for(let j=0;j<lv;j++)sum+=g.labUpgradeCost(keys[i],j);return sum;
},0);
assert.equal(expectedLabCost,24158);
function simulate(seed,{lab=true,pace='moderate',adLimit=2,regular=true,runsPerDay=4}={}){
 assert(ramps[pace]);rng=seed>>>0;const g=game(),s=g.save;
 let runs=0,day=-1,week=-1,month='',adsToday=0,labSpent=0;
 let weekWaves=0,weekClaims=[],seasonXp=0,seasonClaims=[],returnClaims={};
 let questDay=false,challengeDay=false,journeyDone=false;
 let eligibleKills=0,actualMisses=0,actualDrops=0,failedRuns=0;
 const stages={};
 function season(){
  for(let i=0;i<SEASON_REWARDS.length;i++)if(!seasonClaims[i]&&seasonXp>=SEASON_REWARDS[i].xp){
   seasonClaims[i]=true;s.shards+=SEASON_REWARDS[i].shards||0;s.gems+=SEASON_REWARDS[i].gems||0;
  }
 }
 function beginDay(n){
  day=n;adsToday=0;if(!regular)return;
  const date=new Date(Date.UTC(2026,9,9+n)),mm=date.toISOString().slice(0,7),ww=Math.floor((n+4)/7);
  if(mm!==month){month=mm;seasonXp=0;seasonClaims=[];}
  if(ww!==week){week=ww;weekWaves=0;weekClaims=[];}
  const streak=n+1,cycle=((streak-1)%14)+1;
  if(cycle===1)returnClaims={};
  s.shards+=ret.loginShardBase+Math.min(streak,ret.loginStreakCap)*ret.loginShardPerStreak;
  s.gems+=streak%7===0?ret.loginGemWeekly:ret.loginGemNormal;
  seasonXp+=e.dailyLoginSeasonXp;
  s.shards+=ret.chestShardBase+Math.floor(random()*(ret.chestShardRandom+1))+Math.min(streak,ret.chestStreakCap);
  if(random()<ret.chestGemChance)s.gems++;
  for(const goal of [3,7,14])if(cycle>=goal&&!returnClaims[goal]){
   const r=RETURN_REWARDS[goal];returnClaims[goal]=true;s.shards+=r.shards||0;s.gems+=r.gems||0;
  }
  questDay=false;challengeDay=false;season();
 }
 function buy(stage){
  if(!lab)return;
  while(true){
   const choices=keys.map((k,i)=>({k,i,price:g.labUpgradeCost(k,s.lab[k])}))
    .filter(x=>s.lab[x.k]<compact[stage][x.i]&&s.shards>=x.price)
    .sort((a,b)=>a.price-b.price);
   if(!choices.length)break;
   const choice=choices[0],before=s.shards;
   g.buyLab(choice.k);assert.equal(before-s.shards,choice.price,'Lab debited incorrect price');
   labSpent+=choice.price;
  }
 }
 function labsReady(stage){return !lab||keys.every((k,i)=>s.lab[k]>=compact[stage][i]);}
 for(let stage=0;stage<ids.length;stage++){
  const id=ids[stage],contract=DEFENDER_CONTRACTS[id],start=runs;
  let tries=0,failed=0,hits=0;
  while(!s.unlocked.includes(id)){
   if(runs>=900)throw Error('No completion by 900 runs: '+id);
   const t=targetDepth[stage],floor=startDepth[stage],ramp=ramps[pace][stage];
   const nominal=Math.round(floor+(t-floor)*Math.min(1,tries/ramp));
   const badRun=random()<.18?3+Math.floor(random()*9):0;
   const depth=Math.max(1,Math.min(t,nominal-Math.floor(random()*5)-badRun));
   if(depth<contract.minWave){failed++;failedRuns++;}
   const n=Math.floor(runs/runsPerDay);if(n!==day)beginDay(n);
   runs++;tries++;
   const income=lookup[depth],shards=Math.floor(income.rawShards*(1+s.lab.income*.04));
   s.shards+=shards;s.gems+=income.gems;
   if(adsToday<adLimit&&shards>=BALANCE.ads.doubleMinShards){s.shards+=shards;adsToday++;}
   s.bestWave=Math.max(s.bestWave,depth);
   if(regular){
    if(!journeyDone&&depth>=10){journeyDone=true;s.shards+=120;s.gems+=15;}
    if(!questDay&&depth>=12){questDay=true;s.gems+=5;seasonXp+=3*e.dailyQuestSeasonXp;}
    if(!challengeDay&&depth>=e.dailyChallengeFirstClearWave){
     challengeDay=true;s.shards+=e.dailyChallengeShards;s.gems+=e.dailyChallengeGems;
    }
    weekWaves+=depth;seasonXp+=income.xp;
    for(let i=0;i<WEEKLY_REWARDS.length;i++)if(!weekClaims[i]&&weekWaves>=WEEKLY_REWARDS[i].waves){
     weekClaims[i]=true;s.shards+=WEEKLY_REWARDS[i].shards||0;s.gems+=WEEKLY_REWARDS[i].gems||0;
     seasonXp+=e.weeklyClaimSeasonXp;
    }
    season();
   }
   buy(stage);
   for(let w=10;w<=depth;w+=10)if(bossAt(w)===contract.source&&w>=contract.minWave){
    eligibleKills++;hits++;
    if((s.defenderParts[id]||0)>=contract.parts)continue;
    const before=s.defenderParts[id]||0;
    g.rollDefenderFragment(contract.source,w);
    if((s.defenderParts[id]||0)===before)actualMisses++;else actualDrops++;
   }
   if(labsReady(stage)&&g.defenderContractStatus(id).ready)g.unlockDefender(id);
   assert(s.shards>=0&&s.gems>=0,'Currencies went negative');
   assert(!s.unlocked.includes(id)||s.bestWave>=contract.minWave,'Bypassed wave contract gate');
  }
  stages[id]={runs:runs-start,failedBeforeGate:failed,eligibleBossKills:hits};
 }
 assert.equal(s.unlocked.filter(x=>ids.includes(x)).length,5);
 if(lab)assert.equal(labSpent,expectedLabCost,'Unexpected Lab total');
 assert(actualDrops>=20,'Failed to collect required fragments');
 return {runs,days:Math.ceil(runs/runsPerDay),labSpent,eligibleKills,actualMisses,actualDrops,failedRuns,stages};
}
function sample(options){
 const v=Array.from({length:600},(_,i)=>simulate(7919+i*104729,options));
 const q=k=>{const a=v.map(x=>x[k]).sort((a,b)=>a-b);return {p10:a[60],median:a[300],p90:a[540]};};
 return {runs:q('runs'),days:q('days'),failedRuns:q('failedRuns'),
  eligibleKills:q('eligibleKills'),misses:q('actualMisses'),labSpent:v[0].labSpent,
  stages:Object.fromEntries(ids.map(id=>[id,v.map(x=>x.stages[id].runs).sort((a,b)=>a-b)[300]]))};
}
const model=sample({}),noLab=sample({lab:false}),slow=sample({pace:'slow'}),
 noAds=sample({adLimit:0}),fast=sample({pace:'fast'});
assert(model.runs.median>64,'Retries failed to increase effort versus idealized model');
assert(slow.runs.median>model.runs.median,'Slower progression has no grind effect');
assert(noAds.runs.median>=model.runs.median,'Ads unexpectedly increase effort');
assert(noLab.labSpent===0&&model.labSpent===24158);
assert(model.runs.p90<450,'Extremely punitive failure-path progression');
assert(model.eligibleKills.median>=20,'No qualifying bosses encountered');
assert(model.failedRuns.median>0,'Failure model contains no failed gates');
assert(fast.runs.median<slow.runs.median);
console.log('PASS failure/retry contract model '+JSON.stringify({model,noLab,slow,noAds,fast}));
console.log('MODEL ASSUMPTIONS: depth ramps and skill growth after 43 waves are hypothetical; lab power not fed into actual combat; 4 runs/day; perfect boss kills through reached depth; no Rift/achievements/mastery.');
