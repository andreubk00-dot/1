'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const src=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const phone=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
const pc=scripts(src),mobile=scripts(phone);
assert.equal(pc[1],mobile[1],'Game logic differs between PC and mobile');
const nodes=new Map();
function $(id){if(!nodes.has(id)){
 const classes=new Set();nodes.set(id,{innerHTML:'',textContent:'',disabled:false,classList:{
 add:(...v)=>v.forEach(x=>classes.add(x)),remove:(...v)=>v.forEach(x=>classes.delete(x)),
 contains:v=>classes.has(v),toggle:(x,on)=>on?classes.add(x):classes.delete(x)
 }});
}return nodes.get(id);}
const window={addEventListener(){}},document={getElementById:$,hidden:false,querySelector:()=>null,querySelectorAll:()=>[]};
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(pc[1].includes(hook));
new Function('window','document','navigator','performance',pc[0]+'\n'+pc[1].replace(hook,'window.__test={Game,DEFAULT_SAVE,TEXT};'))(window,document,{language:'ru'},{now:()=>0});
const {Game,DEFAULT_SAVE,TEXT}=window.__test;
let count=0;
async function test(name,fn){await fn();count++;console.log('PASS',name);}
function fixture(){
 const g=Object.create(Game.prototype);g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));g.save.quests.doubleAds=0;
 g.t=TEXT.ru;g.lang='ru';g.inRun=false;g.paused=true;g.pauseOverlay=false;g.resultAdBusy=false;
 g.run={wave:40,reached:40,earnedShards:200,earnedGems:7,revived:false,resultDoubled:false,
     core:0,maxCore:100,energy:10,commanderCharge:0,commanderHeat:80,commanderOverheated:true,
     enemies:[],projectiles:[]};
 g.persist=()=>{};g.renderHome=()=>{};g.toast=()=>{};g.track=()=>{};g.showScreen=()=>{};g.waveEnemyCount=()=>5;g.isBossWave=()=>false;
 g.audio={startCombatMusic:()=>{}};
 let pending=null,calls=0;g.bridge={adInProgress:false,gameplayStart:()=>{},
 rewardAd(fn){calls++;return new Promise(resolve=>{pending={fn,resolve};});},
 fullscreen:async()=>false};
 return{g,getPending:()=>pending,getCalls:()=>calls};
}
(async()=>{
 await test('Only one requested double reward, and exit blocked while ad open',async()=>{
   const f=fixture(),g=f.g;const a=g.doubleResult(),b=g.doubleResult();
   assert.equal(f.getCalls(),1);await b;
   await g.leaveResult();assert.equal(g.run?.earnedShards,200);assert.equal(g.resultAdBusy,true);
   f.getPending().fn();f.getPending().resolve(true);await a;
   assert.equal(g.save.shards,200);assert.equal(g.save.quests.doubleAds,1);assert.equal(g.resultAdBusy,false);
   await g.doubleResult();assert.equal(f.getCalls(),1);assert.equal(g.save.shards,200);
 });
 await test('Cancelled ad never grants shards and buttons recover',async()=>{
   const f=fixture(),g=f.g;const a=g.doubleResult();f.getPending().resolve(false);await a;
   assert.equal(g.save.shards,0);assert.equal(g.run.resultDoubled,false);
   assert.equal($('doubleRewardBtn').disabled,false);assert.equal($('reviveBtn').disabled,false);
 });
 await test('Revive cannot race a double reward',async()=>{
   const f=fixture(),g=f.g;const a=g.doubleResult();await g.reviveRun();assert.equal(f.getCalls(),1);
   f.getPending().fn();f.getPending().resolve(true);await a;
   await g.reviveRun();assert.equal(f.getCalls(),1);assert.equal(g.inRun,false);
 });
 await test('Manual exit cannot trigger a revive ad',async()=>{
   const f=fixture();f.g.run.manualEnd=true;await f.g.reviveRun();assert.equal(f.getCalls(),0);
 });
 await test('Revive returns to battle and deducts already-paid run rewards once',async()=>{
   const f=fixture(),g=f.g;g.save.shards=200;g.save.gems=7;
   const p=g.reviveRun();assert.equal(f.getCalls(),1);
   await g.leaveResult();assert(g.run);
   f.getPending().fn();f.getPending().resolve(true);await p;
   assert.equal(g.save.shards,0);assert.equal(g.save.gems,0);assert.equal(g.inRun,true);
   assert.equal(g.run.revived,true);assert.equal(g.run.core,62);
   await g.reviveRun();assert.equal(f.getCalls(),1);
 });
 await test('Daily quest CTA is absent after a claimed reward',async()=>{
   const f=fixture(),g=f.g;
   g.save.journey.claimed=Array(6).fill(true);g.save.weekly.claimed=Array(5).fill(true);
   g.save.quests={day:'x',waves:20,upgrades:8,skills:3,claimed:[true,true,true],doubleAds:0};
   g.save.bestWave=0;g.save.shards=0;g.save.gems=0;
   g.masteryMilestoneReady=()=>false;
   g.renderNextSteps();assert(!($('nextSteps').innerHTML.includes('Забери кристаллы')));
   g.save.quests.claimed[1]=false;
   g.renderNextSteps();assert($('nextSteps').innerHTML.includes('Забери кристаллы'));
   g.save.quests.claimed[1]=true;
   g.renderNextSteps();assert(!($('nextSteps').innerHTML.includes('Забери кристаллы')));
 });
 await test('At most two shard doubles per day across separate runs',async()=>{
   const f=fixture(),g=f.g;
   for(let i=0;i<2;i++){
     g.run={wave:40,reached:40,earnedShards:100,earnedGems:3,resultDoubled:false,revived:false};
     const p=g.doubleResult();f.getPending().fn();f.getPending().resolve(true);await p;
     assert.equal(g.save.quests.doubleAds,i+1);
   }
   g.run={wave:40,reached:40,earnedShards:100,earnedGems:3,resultDoubled:false,revived:false};
   await g.doubleResult();
   assert.equal(f.getCalls(),2);assert.equal(g.save.shards,200);
 });
 await test('Ineligible result cannot claim a rewarded doubling',async()=>{
   const f=fixture();f.g.run.reached=1;await f.g.doubleResult();
   assert.equal(f.getCalls(),0);assert.equal(f.g.save.shards,0);
 });
 await test('Save schema and both platform scripts unchanged',async()=>{
   assert(src.includes('out.version=21'));assert(phone.includes('out.version=21'));
   for(const b of [...pc,...mobile])if(b.trim())new Function(b);
 });
 console.log(count+' economy guard tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});