'use strict';
// Deterministic calendar-aware scenario MODEL, not measured player hours.
// All runs complete all waves/bosses and obtain every kill. No lab expenses,
// losses, Rift, offline income, mastery bonuses, achievements or payments.
// Rich-rewards scenario claims all daily quests/challenge, one chest per day,
// login rewards, and all unlocked weekly, monthly and return milestones.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
const a=scripts(pc),b=scripts(mobile);
assert.equal(a[1],b[1],'PC/mobile game logic differs');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Missing Game extraction hook');
const win={};
new Function('window','document','navigator','performance',
 a[0]+'\n'+a[1].replace(hook,'window.__model={Game,BALANCE,DEFENDER_CONTRACTS,WEEKLY_REWARDS,SEASON_REWARDS,RETURN_REWARDS,JOURNEY};')
)(win,{}, {language:'ru'},{now:()=>0});
const {Game,BALANCE,DEFENDER_CONTRACTS,WEEKLY_REWARDS,SEASON_REWARDS,RETURN_REWARDS,JOURNEY}=win.__model;
const g=Object.create(Game.prototype),e=BALANCE.economy,ret=BALANCE.retentionEconomy;
const ids=['prism','nova','ember','volt','chrono'];
const depths={prism:45,nova:55,ember:65,volt:105,chrono:125};
const bossWave={aegis:10,leech:20,singularity:30};
assert.equal(ids.reduce((s,id)=>s+DEFENDER_CONTRACTS[id].shards,0),48000);
assert.equal(ids.reduce((s,id)=>s+DEFENDER_CONTRACTS[id].gems,0),303);
assert.equal(BALANCE.ads.doubleRewardDailyLimit,2);
assert.equal(JOURNEY.reduce((s,x)=>s+(x.reward.shards||0),0),120);
assert.equal(JOURNEY.reduce((s,x)=>s+(x.reward.gems||0),0)+6,15);
const income={};
for(const id of ids){
 const depth=depths[id];let kills=0,xp=0;
 for(let wave=1;wave<=depth;wave++){
  kills+=g.waveEnemyCount(wave);
  xp+=e.seasonXpWaveBase+Math.floor(wave/e.seasonXpWaveStep);
  if(wave%10===0)xp+=e.bossSeasonXpBase+Math.floor(wave/e.bossSeasonXpStep)*4;
 }
 const bonus=Math.min(e.shardDepthBonusCap,1+Math.max(0,depth-e.shardDepthBonusStartWave)*e.shardDepthBonusPerWave);
 income[id]={depth,xp,shards:Math.floor((depth*e.runShardPerWave+Math.sqrt(kills)*e.runShardKillSqrt)*bonus),
  gems:Math.floor(depth/10)*e.bossGemReward+Math.floor(depth/e.runGemEvery)+(depth>=e.runGemWaveThreshold?1:0)};
}
function simulate(seed,{ads=0,regular=false,runsPerDay=4,chestsPerDay=1,offlineMinutes=0}={}){
 let rng=seed>>>0;
 const random=()=>((rng=(Math.imul(rng,1664525)+1013904223)>>>0)/4294967296);
 let shards=0,gems=0,runs=0,dayNow=-1,weekNow=-1,monthNow='',adsToday=0;
 let weekWaves=0,weekClaims=[],monthXp=0,monthClaims=[],returnClaims={};
 let questsDone=false,challengeDone=false,journeyDone=false;const stages={};
 function claimSeason(){
  for(let i=0;i<SEASON_REWARDS.length;i++)if(!monthClaims[i]&&monthXp>=SEASON_REWARDS[i].xp){
   monthClaims[i]=true;shards+=SEASON_REWARDS[i].shards||0;gems+=SEASON_REWARDS[i].gems||0;
  }
 }
 function beginDay(day){
  dayNow=day;adsToday=0;
  if(!regular)return;
  const date=new Date(Date.UTC(2026,9,9+day)),month=date.toISOString().slice(0,7);
  const week=Math.floor((day+4)/7); // 2026-10-09 is Friday; first Monday is day 3.
  if(month!==monthNow){monthNow=month;monthXp=0;monthClaims=[];}
  if(week!==weekNow){weekNow=week;weekWaves=0;weekClaims=[];}
  const streak=day+1,cycle=((streak-1)%14)+1,streakCap=Math.min(streak,ret.loginStreakCap);
  if(cycle===1)returnClaims={};
  shards+=ret.loginShardBase+streakCap*ret.loginShardPerStreak;
  gems+=streak%7===0?ret.loginGemWeekly:ret.loginGemNormal;
  monthXp+=e.dailyLoginSeasonXp;
  for(let chest=0;chest<chestsPerDay;chest++){
   shards+=ret.chestShardBase+Math.floor(random()*(ret.chestShardRandom+1))+Math.min(streak,ret.chestStreakCap);
   if(random()<ret.chestGemChance)gems++;
  }
  shards+=Math.floor(Math.min(offlineMinutes,ret.offlineCapMinutes)*ret.offlineShardPerMinute);
  for(const milestone of [3,7,14])if(cycle>=milestone&&!returnClaims[milestone]){
   const r=RETURN_REWARDS[milestone];returnClaims[milestone]=true;
   shards+=r.shards||0;gems+=r.gems||0;
  }
  questsDone=false;challengeDone=false;claimSeason();
 }
 for(const id of ids){
  const c=DEFENDER_CONTRACTS[id],run=income[id],start=runs;
  let parts=0,pity=0;
  while(parts<c.parts||shards<c.shards||gems<c.gems){
   if(runs>=1000)throw Error('Incomplete economy model at '+id);
   const day=Math.floor(runs/runsPerDay);if(day!==dayNow)beginDay(day);
   runs++;shards+=run.shards;gems+=run.gems;
   if(adsToday<ads){shards+=run.shards;adsToday++;}
   if(regular){
    if(!journeyDone){journeyDone=true;shards+=120;gems+=15;}
    if(!questsDone){questsDone=true;gems+=5;monthXp+=3*e.dailyQuestSeasonXp;}
    if(!challengeDone){challengeDone=true;shards+=e.dailyChallengeShards;gems+=e.dailyChallengeGems;}
    weekWaves+=run.depth;monthXp+=run.xp;
    for(let i=0;i<WEEKLY_REWARDS.length;i++)if(!weekClaims[i]&&weekWaves>=WEEKLY_REWARDS[i].waves){
     weekClaims[i]=true;shards+=WEEKLY_REWARDS[i].shards||0;gems+=WEEKLY_REWARDS[i].gems||0;
     monthXp+=e.weeklyClaimSeasonXp;
    }
    claimSeason();
   }
   for(let wave=bossWave[c.source];wave<=run.depth;wave+=30){
    if(wave<c.minWave||parts>=c.parts)continue;
    const bonus=Math.min(.12,Math.max(0,Math.floor((wave-c.minWave)/30))*.03);
    if(pity+1>=c.pity||random()<Math.min(.60,c.chance+bonus)){parts++;pity=0;}else pity++;
   }
  }
  shards-=c.shards;gems-=c.gems;stages[id]=runs-start;
 }
 return {runs,stages,days:Math.ceil(runs/runsPerDay)};
}
function sample(options){
 const v=Array.from({length:2000},(_,i)=>simulate(i*1777+1839,options));
 const sort=a=>a.sort((x,y)=>x-y);
 const runs=sort(v.map(x=>x.runs)),days=sort(v.map(x=>x.days));
 return {p10:runs[200],median:runs[1000],p90:runs[1800],days:days[1000],
  stageMedians:Object.fromEntries(ids.map(id=>[id,sort(v.map(x=>x.stages[id]))[1000]]))};
}
const baseline=sample({}),adOnly=sample({ads:2}),regular=sample({regular:true}),
 regularAds=sample({regular:true,ads:2}),frequent=sample({regular:true,ads:2,runsPerDay:8}),
 highClaim=sample({regular:true,ads:2,runsPerDay:8,chestsPerDay:4,offlineMinutes:240});
assert(baseline.median>=70&&baseline.median<=100,'Baseline contract model drifted');
assert(adOnly.median>=55&&adOnly.median<baseline.median,'Ad-only progression drifted');
assert(regular.median<=baseline.median,'Free recurring bonus has no effect');
assert(regularAds.median<=adOnly.median,'Combined bonus has no effect');
assert(regularAds.median>=45,'Recurring+rewarded progression trivialized contracts');
assert(highClaim.median>=45,'Four daily chests plus full offline accrual trivialize contracts');
console.log('PASS calendar economy '+JSON.stringify({baseline,adOnly,regular,regularAds,frequent,highClaim}));
console.log('ASSUMPTIONS: all kills/full-depth clears; maximal quest/challenge claims in calendar mode; no lab spending, Rift, mastery, achievements or failures. Only highClaim includes 4 daily chests and the 240-minute offline cap.');
