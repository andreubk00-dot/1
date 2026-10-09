'use strict';
// Headless smoke simulation of the ACTUAL Game.update loop, not a DPS spreadsheet.
// Usage: node tests/simulate-runs.cjs [profile] [seed] [rangeMultiplier]
// Also exposes contract-ladder snapshots; see tests/combat-contract-ladder-v1824.test.cjs.
// Graphics/audio are mocked, manual fire, Pulse, Commander Mode and inexpensive upgrades are automated.
const fs=require('node:fs'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const scripts=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const elements=new Map();
function el(id){
 if(!elements.has(id)){
  const cls=new Set();
  elements.set(id,{style:{},dataset:{},parentElement:{dataset:{}},
   classList:{add:(...v)=>v.forEach(x=>cls.add(x)),remove:(...v)=>v.forEach(x=>cls.delete(x)),toggle:(x,on)=>on?cls.add(x):cls.delete(x),contains:x=>cls.has(x)},
   textContent:'',innerHTML:'',disabled:false,setAttribute(){},querySelector(){return null}});
 }
 return elements.get(id);
}
const document={getElementById:el,querySelector:()=>null,querySelectorAll:()=>[],dispatchEvent(){},hidden:false};
const window={addEventListener(){},matchMedia(){return{matches:false}}};
let seed=(Number(process.argv[3])||12345)>>>0;
const math=Object.create(Math);
math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const source=scripts[1].replace(
 "window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });",
 "window.__sim={Game,DEFAULT_SAVE,TEXT,RELICS};");
if(!source.includes('window.__sim={Game'))throw Error('Simulator hook missing');
new Function('window','document','navigator','performance','structuredClone','setTimeout','CustomEvent','Math',
 scripts[0]+'\n'+source)(window,document,{language:'ru'},{now:()=>0},
 obj=>JSON.parse(JSON.stringify(obj)),()=>0,function(){},math);
const {Game,DEFAULT_SAVE,TEXT,RELICS}=window.__sim;
const profiles={
 fresh:{damage:0,core:0,income:0,start:0,mastery:1,stars:1,meta:1,units:['sentinel','spark','frost']},
 progressed:{damage:10,core:10,income:6,start:5,mastery:15,stars:3,meta:15,units:['sentinel','spark','frost']},
 veteran:{damage:22,core:18,income:12,start:12,mastery:25,stars:5,meta:45,units:['prism','volt','chrono']},
 // Contract-ladder snapshots. These are combat WHAT-IF profiles, not claims that
 // a player has already earned the upgrades/fragments by any number of runs.
 gatePrism:{damage:9,core:8,income:5,start:5,mastery:12,stars:2,meta:14,units:['sentinel','spark','frost']},
 gateNova:{damage:12,core:10,income:6,start:7,mastery:15,stars:3,meta:25,units:['sentinel','spark','prism']},
 gateVoltWeak:{damage:18,core:16,income:8,start:10,mastery:20,stars:4,meta:35,units:['prism','nova','ember']},
 gateVoltSynergy:{damage:18,core:16,income:8,start:10,mastery:20,stars:4,meta:35,units:['spark','prism','ember']},
 gateChrono:{damage:20,core:16,income:10,start:11,mastery:22,stars:4,meta:40,units:['prism','ember','volt']}
};
const kind=process.argv[2]||'fresh',p=profiles[kind],rangeFactor=Number(process.argv[4]||1);
if(!p||!(rangeFactor>0))throw Error('Invalid simulation parameters');
const g=Object.create(Game.prototype);
g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));
g.t=TEXT.ru;g.lang='ru';g.inRun=false;g.paused=false;g.pauseOverlay=false;g.rmbBoost=false;g.autoLowFx=true;
g.save.runs=1;g.save.lab.damage=p.damage;g.save.lab.core=p.core;g.save.lab.income=p.income;g.save.lab.start=p.start;
g.save.meta.level=p.meta;g.save.meta.spent.damage=Math.floor(p.meta/2);g.save.meta.spent.core=Math.floor(p.meta/3);
g.save.selected=p.units;
for(const id of p.units){g.save.mastery[id]={level:p.mastery,stars:p.stars,xp:0};if(!g.save.unlocked.includes(id))g.save.unlocked.push(id);}
g.bridge={gameplayStart(){},gameplayStop(){},submitScore(){}};
g.audio=new Proxy({}, {get:()=>()=>{}});
g.pauseInternal=v=>{g.paused=!!v};
for(const m of ['track','persist','checkAchievements','checkFieldOrders','haptic','updateBattleHud','renderHome','banner','renderUnitCards','renderFieldOrder','toast','celebrateReward','updateComboHud','renderResultNextGoal','maybeShowUnlockCoach','resizeCanvas','refreshSpeedButton','showScreen','showBossIntro','renderNextSteps','renderMasteryRewards','tickCombatHud','updateBossObjective','spawnBurst','spawnRing','spawnExplosion','spawnArc','spawnBeam','deathFx','impactFeedback'])g[m]=()=>{};
if(rangeFactor!==1){const find=g.findTarget.bind(g);g.findTarget=(u,d)=>find(u,d*rangeFactor);}
g.startRun(false);
const preferred=['warhead','overclock','shield','capacitor','resonance','scavenger','cryo','blast','chain'];
const checkpoints=[],maxTicks=140000,maxWave=120,step=.05;
let previousWave=0,ticks=0,seconds=0,maxEnemies=0,error=null;
try {
 while(g.inRun&&g.run.wave<=maxWave&&ticks<maxTicks){
  const r=g.run;
  if(r.wave!==previousWave){
   if(previousWave&&previousWave%5===0){
    g.presentRelicChoice();
    if(r.currentRelicChoices.length){
     const chosen=preferred.find(id=>r.currentRelicChoices.includes(id))||r.currentRelicChoices[0];
     g.chooseRelic(chosen);
    }
   }
   if([1,5,10,20,30,40,50,60,80,100,120].includes(r.wave)){
    checkpoints.push({wave:r.wave,seconds:Math.round(seconds),core:Math.round(r.core),energy:Math.round(r.energy),levels:r.units.map(u=>u.level)});
   }
   previousWave=r.wave;
  }
  let buys=0;
  while(buys++<6){const u=r.units.reduce((a,b)=>g.unitUpgradeCost(a)<=g.unitUpgradeCost(b)?a:b);if(g.unitUpgradeCost(u)>r.energy)break;g.upgradeUnit(r.units.indexOf(u));}
  const target=r.enemies.find(e=>e.boss&&e.hp>0)||r.enemies.filter(e=>e.hp>0&&e.x>110).sort((a,b)=>a.x-b.x)[0];
  if(target){
   const weak=target.boss&&target.weakOpen>0?g.weakPointPos(target):null;
   r.aim=weak||{x:target.x,y:target.y};r.holdFire=true;
   if(r.skillCd<=0 && (target.boss || r.enemies.length>=3))g.usePulse();
  }else r.holdFire=false;
  if((r.commanderCharge||0)>=100 && !r.commanderModeTimer)g.activateCommanderMode();
  g.update(step);
  seconds+=step;ticks++;maxEnemies=Math.max(maxEnemies,r.enemies.length);
 }
}catch(e){error=e.stack;}
const report={profile:kind,seed:Number(process.argv[3]||12345),rangeMultiplier:rangeFactor,
 reached:g.run?.wave||0,cleared:g.run?.lastCleared||0,alive:g.inRun,
 core:Math.round(g.run?.core||0),energy:Math.round(g.run?.energy||0),
 seconds:Math.round(seconds),ticks,maxEnemies,checkpoints,error};
console.log(JSON.stringify(report));
if(error)process.exitCode=1;
