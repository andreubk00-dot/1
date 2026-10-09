'use strict';
// Fixed-depth progression STRESS AUDIT, not player telemetry or simulated wins.
// Uses actual Game.gainDefenderMastery, claimMasteryReward, promoteDefender,
// grantBlueprints, gainMetaXp, and Lab prices. Unlike Game.update() combat,
// each test round assumes every wave and boss through its fixed depth is cleared.
// No paid ads, daily rewards, achievements, seasons, Rift, or income Lab bonus.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8'),
 mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const a=scripts(pc),b=scripts(mobile);
assert.equal(a[1],b[1],'PC/mobile mastery rules diverged');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Game extraction hook missing');
let rng=12345;
const random=()=>((rng=(Math.imul(rng,1664525)+1013904223)>>>0)/4294967296);
const math=Object.create(Math);math.random=random;
const win={};
new Function('window','document','navigator','performance','Math','setTimeout',
 a[0]+'\n'+a[1].replace(hook,
 'window.__mastery={Game,BALANCE,DEFAULT_SAVE,LABS,DEFENDER_CONTRACTS,TEXT,MASTERY_MILESTONES,PROMOTION_COSTS,PROMOTION_BLUEPRINT_COSTS};')
)(win,{}, {language:'ru'},{now:()=>0},math,()=>0);
const {Game,BALANCE,DEFAULT_SAVE,LABS,DEFENDER_CONTRACTS,TEXT,
 MASTERY_MILESTONES,PROMOTION_COSTS,PROMOTION_BLUEPRINT_COSTS}=win.__mastery;
const e=BALANCE.economy,units=['spark','prism','ember'],costLab={damage:18,core:16,income:8,start:10};
function game(){
 const g=Object.create(Game.prototype);
 g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));g.lang='ru';g.t=TEXT.ru;
 g.audio=new Proxy({}, {get:()=>()=>{}});
 for(const fn of ['toast','persist','renderHome','renderCollection','renderMasteryRewards','celebrateReward','track'])
  g[fn]=()=>{};
 g.save.selected=units.slice();
 g.save.unlocked=[...new Set([...g.save.unlocked,...units])];
 return g;
}
const g=game();
const sumPromotion=(arr,upTo)=>arr.slice(1,upTo).reduce((s,v)=>s+v,0);
assert.equal(sumPromotion(PROMOTION_COSTS,4),58);
assert.equal(sumPromotion(PROMOTION_BLUEPRINT_COSTS,4),29);
assert.equal(sumPromotion(PROMOTION_COSTS,5),106);
assert.equal(sumPromotion(PROMOTION_BLUEPRINT_COSTS,5),55);
assert.equal(MASTERY_MILESTONES.filter(v=>v.level<=20).reduce((s,v)=>s+(v.blueprints||0),0),25,
 'Milestone blueprint drop must not be treated as enough to buy 4★ alone');
assert.equal(MASTERY_MILESTONES.filter(v=>v.level<=20).reduce((s,v)=>s+(v.gems||0),0),6);
let xp20=0;for(let n=1;n<20;n++)xp20+=g.masteryXpNeed(n);
assert.equal(xp20,3346);
const coreXp={};for(const rank of [14,25,35,40]){
 let s=0;for(let l=1;l<rank;l++)s+=g.metaXpNeed(l);
 coreXp[rank]=s;
}
assert.deepEqual(coreXp,{14:3146,25:19893,35:97452,40:214237});
const labCosts=Object.entries(costLab).reduce((sum,[key,lv])=>{
 assert(lv<=LABS[key].max);for(let l=0;l<lv;l++)sum+=g.labUpgradeCost(key,l);return sum;
},0);
assert.equal(labCosts,81136);
const existingContracts=['prism','nova','ember'],nextContract='volt';
const priorShards=existingContracts.reduce((s,id)=>s+DEFENDER_CONTRACTS[id].shards,0);
const priorGems=existingContracts.reduce((s,id)=>s+DEFENDER_CONTRACTS[id].gems,0);
const totalShardTarget=labCosts+priorShards+DEFENDER_CONTRACTS[nextContract].shards;
const remainingContractGems=priorGems+DEFENDER_CONTRACTS[nextContract].gems;
const totalGemTarget=remainingContractGems+units.length*58;
assert.equal(remainingContractGems,178);
assert.equal(totalShardTarget,109136);
assert.equal(totalGemTarget,352);
function simulate(seed,depth,maxRuns=550){
 rng=seed>>>0;const g=game(),save=g.save,record={};
 const snapshots=Object.fromEntries(units.map(id=>[id,{star4:0,level20:0,blueprints:0}]));
 let bossCount=0,kills=0;
 for(let w=1;w<=depth;w++)kills+=g.waveEnemyCount(w);
 const depthBonus=Math.min(e.shardDepthBonusCap,1+Math.max(0,depth-e.shardDepthBonusStartWave)*e.shardDepthBonusPerWave);
 const earnedPerRun=Math.floor((depth*e.runShardPerWave+Math.sqrt(kills)*e.runShardKillSqrt)*depthBonus);
 let gemsEarned=0,spentGems=0;
 for(let run=1;run<=maxRuns;run++){
  for(let w=1;w<=depth;w++){
   g.gainDefenderMastery(e.masteryWaveBase+Math.floor(w/e.masteryWaveStep));
   g.gainMetaXp(e.coreXpWaveBase+Math.floor(w/e.coreXpWaveStep));
   if(w%10===0){
    bossCount++;
    g.gainDefenderMastery(24+Math.floor(w/3));
    g.gainMetaXp(e.bossCoreXpBase+w*e.bossCoreXpPerWave);
    save.gems+=e.bossGemReward;gemsEarned+=e.bossGemReward;
    if(bossCount%e.bossBlueprintEvery===0){
     const amount=Math.min(3,e.bossBlueprintBase+Math.floor(w/e.bossBlueprintStep));
     g.grantBlueprints(amount);
    }
   }
   if(w%e.runGemEvery===0){save.gems++;gemsEarned++;}
  }
  if(depth>=e.runGemWaveThreshold){save.gems++;gemsEarned++;}
  save.shards+=earnedPerRun;
  for(const id of units){
   for(let i=0;i<MASTERY_MILESTONES.length;i++){
    if(g.masteryState(id).level>=MASTERY_MILESTONES[i].level){
     g.claimMasteryReward(id,i);
    }
   }
   // Spend only earned gems and blueprint drops; never seed promotions with free currency.
   while(g.masteryState(id).stars<4){
    const prev=g.masteryState(id).stars,before=save.gems;
    g.promoteDefender(id);
    if(g.masteryState(id).stars===prev)break;
    spentGems+=before-save.gems;
   }
   const s=snapshots[id],m=g.masteryState(id);
   if(!s.star4&&m.stars>=4)s.star4=run;
   if(!s.level20&&m.level>=20)s.level20=run;
   s.blueprints=save.blueprints[id]||0;
  }
  if(!record.star4All&&units.every(id=>g.masteryState(id).stars>=4))record.star4All=run;
  if(!record.level20All&&units.every(id=>g.masteryState(id).level>=20))record.level20All=run;
  for(const rank of [14,25,35,40])if(!record['meta'+rank]&&save.meta.level>=rank)record['meta'+rank]=run;
  if(!record.gemsForContracts&&save.gems>=remainingContractGems)record.gemsForContracts=run;
  if(!record.shardsForLab&&save.shards>=labCosts)record.shardsForLab=run;
  if(!record.shardsForPriorContractsAndNextLab&&save.shards>=totalShardTarget)record.shardsForPriorContractsAndNextLab=run;
  if(!record.fullSnapshotBudget&&record.level20All&&record.star4All&&record.meta35&&
     record.shardsForPriorContractsAndNextLab&&record.gemsForContracts)
   record.fullSnapshotBudget=run;
  if(record.fullSnapshotBudget)break;
 }
 assert(record.fullSnapshotBudget&&record.level20All&&record.star4All&&record.meta35&&
   record.shardsForPriorContractsAndNextLab&&record.gemsForContracts,
  'Unreachable fixed-depth scenario '+depth);
 assert(save.gems>=0&&save.shards>=0,'Negative currency during legitimate progression');
 assert.equal(spentGems,58*3,'Unexpected spent promotion gems');
 assert.equal(save.meta.level-1,save.meta.tokens,
  'Meta tokens should remain unspent and track rank-ups');
 assert(g.masteryState(units[0]).stars>=4);
 return {...record,earnedPerRun,gemsEarned,bossCount,left:{shards:save.shards,gems:save.gems},snapshots};
}
function summary(depth){
 const samples=Array.from({length:40},(_,i)=>simulate(i*911+1419,depth));
 const fields=['star4All','level20All','meta14','meta25','meta35','gemsForContracts','fullSnapshotBudget',
  'shardsForLab','shardsForPriorContractsAndNextLab'];
 const values=Object.fromEntries(fields.map(key=>{
  const a=samples.map(x=>x[key]).sort((a,b)=>a-b);
  return [key,{p10:a[4],median:a[20],p90:a[36]}];
 }));
 return {depth,earnedPerRun:samples[0].earnedPerRun,values};
}
const results=[45,65,85,105].map(summary);
for(const row of results){
 assert(row.values.meta35.median>row.values.level20All.median,
  'Commander/meta progression unexpectedly easier than defender mastery');
 assert(row.values.shardsForPriorContractsAndNextLab.median>row.values.shardsForLab.median,
  'Contract budget vanished');
 assert(row.values.star4All.p90<90,'Blueprint RNG became excessive');
}
for(let i=1;i<results.length;i++){
 assert(results[i].values.meta35.median<results[i-1].values.meta35.median,
  'Deeper boss kills do not advance Core rank faster');
}
console.log('PASS permanent progression/resource audit '+JSON.stringify({coreXp,xp20,labCosts,
 totalShardTarget,totalGemTarget,results}));
console.log('ASSUMPTIONS: preunlocked Spark, Prism and Ember; no actual combat losses; all bosses through fixed depth die; no ad, daily, weekly, season, Rift or achievement resources. Prices are real; Lab/contracts shard and gem budgets are checked as affordability snapshots, not actually bought during fixed-depth runs. Runs are NOT real playtime.');
