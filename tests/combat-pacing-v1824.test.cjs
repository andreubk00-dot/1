'use strict';
// Fixed-seed combat pacing gates. Reuses the actual Game.update() headless simulator.
// Wide thresholds detect accidental trivialization of the starter squad or a wall
// against established players without freezing exact RNG/combat outcomes.
const assert=require('node:assert/strict');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const sim=path.join(__dirname,'simulate-runs.cjs');
const seeds=[12345,42,8675309];
const profiles={
 fresh:{min:25,max:35,alive:false,minSeconds:450,maxSeconds:950},
 progressed:{min:40,max:60,alive:false,minSeconds:900,maxSeconds:1800},
 veteran:{min:120,max:121,alive:true,minSeconds:2200,maxSeconds:4500}
};
const results={};
for(const [profile,guard] of Object.entries(profiles)){
 results[profile]=[];
 for(const seed of seeds){
  const output=execFileSync(process.execPath,[sim,profile,String(seed),'1'],{
   encoding:'utf8',timeout:60000,maxBuffer:2*1024*1024
  }).trim();
  const report=JSON.parse(output.split('\n').at(-1));
  assert.equal(report.error,null,profile+' combat simulator errored');
  assert.equal(report.profile,profile);
  assert.equal(report.seed,seed);
  assert(report.reached>=guard.min&&report.reached<=guard.max,
   profile+' reached unexpected wave '+report.reached);
  assert.equal(report.alive,guard.alive,profile+' survival state drifted');
  assert(report.seconds>=guard.minSeconds&&report.seconds<=guard.maxSeconds,
   profile+' simulated time unexpectedly changed '+report.seconds);
  results[profile].push(report.reached);
 }
}
for(let i=0;i<seeds.length;i++){
 assert(results.fresh[i]<results.progressed[i],'Starter team overtook progressed team');
 assert(results.progressed[i]<results.veteran[i],'Progressed team overtook veteran team');
}
console.log('PASS combat progression gates '+JSON.stringify(results));
console.log('Headless simulated seconds are NOT actual player-session durations.');
