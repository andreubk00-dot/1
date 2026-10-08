'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const js=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const scripts=js(html),mobileScripts=js(mobile);
assert.equal(scripts[0],mobileScripts[0]);assert.equal(scripts[1],mobileScripts[1]);
for(const body of scripts)if(body.trim())new Function(body);
for(const body of mobileScripts)if(body.trim())new Function(body);
const fake={};const ids=new Map();
function el(id){if(!ids.has(id)){const set=new Set();ids.set(id,{innerHTML:'',textContent:'',disabled:false,classList:{add:v=>set.add(v),remove:v=>set.delete(v)}});}return ids.get(id);}
const main=scripts[1].replace("window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });","window.__balanceTest={Game,BALANCE,DEFAULT_SAVE,RELICS};");
assert(main.includes('window.__balanceTest='));
new Function('window','document','navigator','performance',scripts[0]+'\n'+main)(fake,{getElementById:el,querySelectorAll:()=>[]},{language:'ru'},{now:()=>0});
const {Game,BALANCE,DEFAULT_SAVE,RELICS}=fake.__balanceTest;
let checks=0;function test(msg,cb){assert(cb(),msg);checks++;console.log('PASS',msg);}
const g=Object.create(Game.prototype);g.lang='ru';g.t={bossAegis:'A',bossLeech:'L',bossSingularity:'S',bossAegisAbility:'a',bossLeechAbility:'l',bossSingularityAbility:'s',reroll:'Reroll',rerolls:'Rerolls',relicTaken:'Chosen {name}'};
g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));g.run={rift:null,challengeHp:1,challengeSpeed:1,firstRun:false};
const old=w=>BALANCE.wave.hpBase*Math.pow(BALANCE.wave.hpEarlyGrowth,Math.min(29,Math.max(0,w-1)))*Math.pow(1.115,Math.max(0,w-30));
test('First 30 waves exactly retain HP',()=>[1,10,20,30].every(w=>Math.abs(old(w)-g.waveHp(w))<1e-8));
test('Late HP curve monotonically rises',()=>[30,40,50,60,80,100,120].every((w,i,a)=>i===0||g.waveHp(w)>g.waveHp(a[i-1])));
test('Wave 100 HP is under 1% of old value',()=>g.waveHp(100)<old(100)*.01);
test('Late boss dampening applied',()=>{const a=g.bossSpec(100);return g.bossHp(100,a)>30000&&g.bossHp(100,a)<40000;});
test('Spawn path delegates boss HP to dampened formula',()=>html.includes('hp=this.bossHp(w,b)'));

g.inRun=true;g.paused=false;g.rmbBoost=true;g.run.speed=1;let ticks=[],calls=0;g.update=v=>{ticks.push(v);calls++};
g.stepCombat(.05);test('Holding RMB progresses all timers 3x',()=>Math.abs(ticks.reduce((a,b)=>a+b,0)-.15)<1e-10&&calls>=5);
g.rmbBoost=false;g.run.speed=.5;ticks=[];g.stepCombat(.05);test('Half speed advances whole simulation at half rate',()=>Math.abs(ticks.reduce((a,b)=>a+b,0)-.025)<1e-10);
g.paused=true;calls=0;g.stepCombat(.05);test('Pause freezes simulation',()=>calls===0);
g.paused=false;g.run={wave:50,relics:Object.keys(RELICS),currentRelicChoices:[],mods:{rate:1,damage:1,waveReward:1,skillCd:1,slowBonus:1,chainBonus:0,splash:1,shardBonus:1,coreGuard:1},rerolls:2};
g.bridge={gameplayStop(){},gameplayStart(){}};g.pauseInternal=()=>{};g.track=()=>{};g.persist=()=>{};g.toast=()=>{};g.checkAchievements=()=>{};g.checkFieldOrders=()=>{};
g.presentRelicChoice();
test('Veteran choices exist after all nine base relics',()=>g.run.veteranMode&&g.run.currentRelicChoices.length===3);
test('Reroll is disabled on veteran selection',()=>el('relicRerollBtn').disabled);
g.chooseRelic('shield');
test('Disallowed relic IDs cannot bypass offered choices',()=>g.run.relics.length===9);
g.chooseRelic('warhead');
test('Repeatable late relic grants reduced stat bonus',()=>g.run.mods.damage===1.08&&g.run.relics.length===9);
const sw=fs.readFileSync(path.join(__dirname,'..','iphone','service-worker.js'),'utf8');
test('PWA cache version advances with balanced build',()=>sw.includes('ed-mobile-v1.8.21'));
test('Save schema retained unchanged',()=>html.includes('out.version=21')&&mobile.includes('out.version=21'));
test('Early Lab prices remain unchanged through level eight',()=>Object.entries({damage:[55,1.55],core:[50,1.52],income:[75,1.62],start:[45,1.50]}).every(([k,[base,growth]])=>Array.from({length:9},(_,level)=>{g.save.lab[k]=level;return g.labUpgradeCost(k)===Math.floor(base*Math.pow(growth,level))}).every(Boolean)));
test('All Lab late costs grow monotonically',()=>Object.keys(g.save.lab).every(k=>Array.from({length:20},(_,i)=>g.labUpgradeCost(k,i+1)>g.labUpgradeCost(k,i)).every(Boolean)));
test('Lab price uses one function for UI, tips and purchase',()=>html.includes('const lv=this.save.lab[k]||0,cost=this.labUpgradeCost(k,lv)')&&html.includes('s.shards>=this.labUpgradeCost(k,lv)')&&html.includes('const lv=this.save.lab[k],cost=this.labUpgradeCost(k,lv)'));

test('Battle upgrade cost unchanged through level nine',()=>Array.from({length:9},(_,i)=>g.unitUpgradeCost({level:i+1})===Math.floor(BALANCE.economy.unitUpgradeBase*Math.pow(BALANCE.economy.unitUpgradeGrowth,i))).every(Boolean));
test('Battle upgrade cost grows more gently past pivot',()=>g.unitUpgradeCost({level:20})<Math.floor(BALANCE.economy.unitUpgradeBase*Math.pow(BALANCE.economy.unitUpgradeGrowth,19)));
test('Later upgrade damage multiplies without altering early levels',()=>Math.abs(g.unitDamageMultiplier(8)-(1+7*.42))<1e-10&&g.unitDamageMultiplier(20)>g.unitDamageMultiplier(10));
test('Progression range is capped and non-decreasing',()=>{g.save.lab.damage=0;g.save.mastery.sentinel={level:1,stars:1,xp:0};const early=g.masteryBonuses('sentinel').range;g.save.lab.damage=30;g.save.mastery.sentinel={level:25,stars:5,xp:0};const late=g.masteryBonuses('sentinel').range;return early===1&&late>early&&late<=1.85;});

test('Rift easing never alters waves 1 through 30',()=>[1,10,20,30].every(w=>g.riftEase(w).hp===1&&g.riftEase(w).speed===1));
test('Rift easing is smooth and reversible through wave 55',()=>{const a=[30,31,34,35,40,45,50,54,55,56].map(w=>g.riftEase(w));return a.every(x=>x.hp>=.70&&x.hp<=1&&x.speed>=.88&&x.speed<=1)&&a[3].hp===.70&&a[3].speed===.88&&a[8].hp===1&&a[8].speed===1&&a[9].hp===1;});
test('Rift pacing applied only to normal enemies, not bosses',()=>html.includes('const ease=this.riftEase(w),hp=this.waveHp(w)*hpMul*ease.hp')&&html.includes('speed:this.waveSpeed(w)*speedMul*affixSpeed*ease.speed')&&html.includes('const b=this.bossSpec(w),v=b.variant||{},hp=this.bossHp(w,b)'));
console.log(checks+' balance checks passed');
