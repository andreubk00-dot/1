'use strict';
// v1.8.24 regression: recurring rewards remain one-shot, including after save normalization.
// Test the actual Game reward methods. No economic coefficients or production code are changed.
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const read=dir=>fs.readFileSync(path.join(__dirname,'..',dir,'index.html'),'utf8');
const pc=read('pc'),mobile=read('iphone');
const scripts=html=>[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const a=scripts(pc),b=scripts(mobile);
assert.equal(a[1],b[1],'PC and mobile gameplay scripts diverged');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Missing regression entry point');
const win={};
new Function('window','document','navigator','performance',
  a[0]+'\n'+a[1].replace(hook,'window.__rewardQA={Game,TEXT,DEFAULT_SAVE,JOURNEY,SEASON_REWARDS,dayKey,weekKey,monthKey};')
)(win,{}, {language:'ru'},{now:()=>0});
const {Game,TEXT,DEFAULT_SAVE,JOURNEY,SEASON_REWARDS,dayKey,weekKey,monthKey}=win.__rewardQA;
const g=Object.create(Game.prototype);
g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));g.lang='ru';g.t=TEXT.ru;
g.audio=new Proxy({}, {get:()=>()=>{}});
for(const name of ['track','toast','celebrateReward','persist','renderHome','renderWeekly','renderSeason','renderJourney','renderReturnTrack'])g[name]=()=>{};
const snapshot=()=>({
  shards:g.save.shards,gems:g.save.gems,
  blueprints:Object.values(g.save.blueprints).reduce((sum,n)=>sum+n,0)
});
const once=fn=>{fn();const first=snapshot();fn();assert.deepEqual(snapshot(),first,'Reward was granted twice');};
const diff=(a,b)=>({shards:b.shards-a.shards,gems:b.gems-a.gems,blueprints:b.blueprints-a.blueprints});
const check=(label,before,expected)=>{
  assert.deepEqual(diff(before,snapshot()),expected,label+' reward budget changed');
  console.log('PASS',label);
};
const none={shards:0,gems:0,blueprints:0};
g.save.quests={day:dayKey(),waves:100,upgrades:100,skills:100,claimed:[false,false,false],doubleAds:0,challengeRewarded:false};
g.save.weekly={week:weekKey(),waves:200,claimed:[false,false,false,false,false]};
g.save.season={key:monthKey(),xp:0,claimed:Array(SEASON_REWARDS.length).fill(false)};
g.save.streak=14;
g.save.returnTrack={cycleStart:dayKey(),cycleIndex:0,claimed:{3:false,7:false,14:false}};
g.save.bestWave=120;Object.assign(g.save.stats,{upgrades:3,skills:2,relics:1,bosses:1});
let before=snapshot();
for(let i=0;i<3;i++)once(()=>g.claimQuest(i));
check('Daily quests: 5 gems, no duplicate claim',before,{shards:0,gems:5,blueprints:0});
assert.equal(g.save.season.xp,30,'Daily quest season XP awarded twice');
before=snapshot();
for(let i=0;i<5;i++)once(()=>g.claimWeekly(i));
check('Weekly rewards: 190 shards and 12 gems',before,{shards:190,gems:12,blueprints:0});
assert.equal(g.save.season.xp,130,'Weekly season XP awarded twice');
g.save.season.xp=1800;
before=snapshot();
for(let i=0;i<SEASON_REWARDS.length;i++)once(()=>g.claimSeason(i));
check('Season rewards: 370 shards, 18 gems, 6 blueprints',before,{shards:370,gems:18,blueprints:6});
before=snapshot();
for(const day of [3,7,14])once(()=>g.claimReturnMilestone(day));
check('Return track: 260 shards, 10 gems, 6 blueprints',before,{shards:260,gems:10,blueprints:6});
before=snapshot();
for(let i=0;i<JOURNEY.length;i++)once(()=>g.claimJourney(i));
check('One-time rookie goals plus completion bonus',before,{shards:120,gems:15,blueprints:0});
assert.equal(g.save.journey.bonusClaimed,true,'Rookie completion reward was not recorded');
assert.deepEqual(diff(none,snapshot()),{shards:940,gems:60,blueprints:12},
  'Combined guaranteed rewards changed');
before=snapshot();
g.save.nextChestAt=0;g.claimReturnReward();
const afterChest=snapshot(),chestTime=g.save.nextChestAt;
assert(afterChest.shards>before.shards,'Return chest did not grant shards');
g.claimReturnReward();
assert.deepEqual(snapshot(),afterChest,'Chest claimed twice before cooldown');
assert.equal(g.save.nextChestAt,chestTime,'Chest cooldown changed on repeat claim');
console.log('PASS Return chest cannot be reclaimed before cooldown');
const beforeReload=snapshot();
const old=JSON.parse(JSON.stringify(g.save));old.version=20;
g.save=g.normalizeSave(old);
assert.equal(g.save.version,21,'Save migration version changed');
assert.deepEqual(snapshot(),beforeReload,'Save normalization changed currencies');
for(let i=0;i<3;i++)g.claimQuest(i);
for(let i=0;i<5;i++)g.claimWeekly(i);
for(let i=0;i<SEASON_REWARDS.length;i++)g.claimSeason(i);
for(const day of [3,7,14])g.claimReturnMilestone(day);
for(let i=0;i<JOURNEY.length;i++)g.claimJourney(i);
g.claimReturnReward();
assert.deepEqual(snapshot(),beforeReload,'Reward duplicated after restoring an old save');
console.log('PASS Claimed rewards survive v20 to v21 normalization');
assert(pc.includes('out.version=21')&&mobile.includes('out.version=21'),'Save schema unexpectedly changed');
const dailyClaims=g.save.quests.claimed.slice(),weeklyClaims=g.save.weekly.claimed.slice();
g.ensureDaily();g.ensureWeekly();
assert.deepEqual(g.save.quests.claimed,dailyClaims,'Daily claims reset within the same day');
assert.deepEqual(g.save.weekly.claimed,weeklyClaims,'Weekly claims reset within the same week');
g.save.quests.day='2000-01-01';g.save.weekly.week='2000-W01';
g.ensureDaily();g.ensureWeekly();
assert.equal(g.save.quests.day,dayKey(),'Daily reward period did not advance');
assert.equal(g.save.weekly.week,weekKey(),'Weekly reward period did not advance');
assert.deepEqual(g.save.quests.claimed,[false,false,false],'Daily claims were not reset for a new period');
assert.deepEqual(g.save.weekly.claimed,[false,false,false,false,false],'Weekly claims were not reset for a new period');
console.log('PASS Claim flags reset only when the day/week changes');
console.log('8 economy reward regression groups passed');
