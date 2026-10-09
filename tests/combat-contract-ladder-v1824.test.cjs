'use strict';
// Actual Game.update() (manual fire, Pulse, Commander Mode, and automatic battle
// upgrades) across seeded contract-stage squad snapshots. NOT a full player
// telemetry / long-horizon earning model, and NOT a guarantee of progression.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {execFileSync}=require('node:child_process');
const profiles=require('./combat-profiles-v1824.cjs'),sim=path.join(__dirname,'simulate-runs.cjs');
const root=path.join(__dirname,'..'),pc=fs.readFileSync(path.join(root,'pc','index.html'),'utf8'),
 phone=fs.readFileSync(path.join(root,'iphone','index.html'),'utf8');
const extract=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const a=extract(pc),b=extract(phone);
assert.equal(a[1],b[1],'Game logic differs on PC and phone');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Game hook missing');
const w={};
new Function('window','document','navigator','performance',
 a[0]+'\n'+a[1].replace(hook,'window.__q={Game,LABS,DEFENDER_CONTRACTS};')
)(w,{}, {language:'ru'},{now:()=>0});
const {Game,LABS,DEFENDER_CONTRACTS}=w.__q,g=Object.create(Game.prototype);
const wanted=['gatePrism','gateNova','gateVoltWeak','gateVoltSynergy','gateChrono'];
const seeds=[12345,42,8675309],result={};
function price(p){
 return Object.keys(LABS).reduce((sum,key)=>{
  const level=p[key];assert(Number.isInteger(level)&&level>=0&&level<=LABS[key].max,
   'Invalid Lab level in contract snapshot '+key);
  for(let i=0;i<level;i++)sum+=g.labUpgradeCost(key,i);
  return sum;
 },0);
}
const labCosts=Object.fromEntries(wanted.map(id=>[id,price(profiles[id])]));
assert(labCosts.gatePrism<labCosts.gateNova);
assert(labCosts.gateNova<labCosts.gateVoltSynergy);
assert(labCosts.gateVoltSynergy<labCosts.gateChrono);
assert(labCosts.gateVoltSynergy>=70000&&labCosts.gateVoltSynergy<=100000,
 'Gate-100 qualifying squad is unrealistically cheap or too expensive');
assert.equal(labCosts.gateVoltWeak,labCosts.gateVoltSynergy,
 'Only unit selection may vary in the equal-investment squad comparison');
const common=['damage','core','income','start','mastery','stars','meta'];
for(const key of common)assert.equal(profiles.gateVoltWeak[key],profiles.gateVoltSynergy[key]);
for(const id of wanted){
 const p=profiles[id];assert.equal(p.units.length,3);
 assert.equal(new Set(p.units).size,3,'Duplicate selected defender');
 assert(p.mastery<=g.masteryCap(p.stars),'Mastery snapshot exceeds star cap');
 result[id]=[];
 for(const seed of seeds){
  const raw=execFileSync(process.execPath,[sim,id,String(seed),'1'],
   {encoding:'utf8',timeout:90000,maxBuffer:2*1024*1024}).trim();
  const report=JSON.parse(raw.split('\n').at(-1));
  assert.equal(report.error,null,id+' runtime error');
  assert.equal(report.profile,id);assert.equal(report.seed,seed);
  assert(report.ticks<140000,'Combat reached guard timeout');
  assert(report.reached>0,'Combat never started');
  result[id].push(report.reached);
 }
}
function between(id,lo,hi){
 for(const w of result[id])assert(w>=lo&&w<=hi,
  id+' reached unexpected wave '+w+' (expected '+lo+'-'+hi+')');
}
between('gatePrism',35,50);
between('gateNova',50,85);
between('gateVoltWeak',50,80);
between('gateVoltSynergy',80,121);
between('gateChrono',70,121);
assert(result.gatePrism.some(w=>w>=DEFENDER_CONTRACTS.prism.minWave),
 'No starting-squad build can approach Prism contract wave 40');
assert(result.gateNova.some(w=>w>=DEFENDER_CONTRACTS.nova.minWave),
 'Prism build cannot clear the Nova contract wave 50');
assert(result.gateNova.some(w=>w>=DEFENDER_CONTRACTS.ember.minWave),
 'Prism build cannot reach Ember 60 gate even on one seed');
assert(result.gateVoltWeak.every(w=>w<DEFENDER_CONTRACTS.volt.minWave),
 'Weaker composition suddenly trivialized pre-Volt gate');
assert(result.gateVoltSynergy.some(w=>w>=DEFENDER_CONTRACTS.volt.minWave),
 'No pre-Volt squad reaches the actual wave-100 contract gate');
assert(result.gateVoltSynergy.some(w=>w<DEFENDER_CONTRACTS.volt.minWave),
 'Every pre-Volt seed clears 100; hard gate may be trivialized');
assert(result.gateChrono.some(w=>w>=DEFENDER_CONTRACTS.chrono.minWave),
 'No pre-Chrono squad reaches wave 120');
for(let i=0;i<seeds.length;i++)assert(result.gateVoltSynergy[i]>result.gateVoltWeak[i],
 'Equal-cost squad choice did not matter for seed '+seeds[i]);
console.log('PASS stage-specific combat gate QA '+JSON.stringify({labCosts,results:result}));
console.log('ASSUMPTIONS: all mastery/star/meta/defender unlocks are pre-granted in QA snapshots. No claim these can be earned in a known run count. High-stage progression and fragment accessibility require gameplay testing.');
