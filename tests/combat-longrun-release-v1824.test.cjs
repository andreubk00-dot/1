'use strict';
// Long-run release guard: executes the real Game.update combat system headlessly,
// with deterministic user assistance (manual fire, Pulse, upgrades, relic picks).
// These are simulated game-time runs, NOT recordings of unassisted human play.
const assert=require('node:assert/strict');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const executable=path.join(__dirname,'simulate-runs.cjs');
const trials=[
 ['fresh',[81,404,20261015,9917301]],
 ['progressed',[97,512,739391,424242]],
 ['veteran',[43,1919,202617,710091]]
];
const summary={};
for(const [profile,seeds] of trials){
  summary[profile]=[];
  for(const seed of seeds){
    const output=execFileSync(process.execPath,[executable,profile,String(seed),'1','audit'],{
      encoding:'utf8',timeout:90000,maxBuffer:1024*1024
    });
    const data=JSON.parse(output.trim().split('\n').at(-1));
    const label=profile+' seed '+seed;
    assert.equal(data.error,null,label+' Game.update exception');
    assert(data.audit&&data.audit.checks>100,label+' missing state invariant samples');
    assert.deepEqual(data.audit.issues,[],label+' invalid state');
    assert(data.reached>=20,label+' died or stalled before meaningful waves');
    assert(data.audit.bossWaves.includes(10),label+' never encountered first boss');
    if(profile!=='fresh'){
      assert(data.audit.bossWaves.includes(20),label+' missed second boss');
      assert(data.audit.bossWaves.includes(30),label+' missed third boss');
    }
    if(profile==='veteran'){
      assert.equal(data.reached,120,label+' failed to reach late-wave gate');
      assert.equal(data.alive,true,label+' veteran progression prematurely terminated');
      assert(data.audit.bossWaves.includes(100),label+' did not reach late boss cycle');
    }
    assert(data.ticks<140000,label+' hit simulation timeout/stalled');
    assert(data.audit.max.enemies<1200,label+' enemy accumulation leaked');
    assert(data.audit.max.projectiles<1200,label+' projectile accumulation leaked');
    summary[profile].push({seed,reached:data.reached,seconds:data.seconds,ticks:data.ticks,
      bosses:data.audit.bossWaves.length,max:data.audit.max});
    console.log('PASS longrun '+label+' wave '+data.reached+
      ' boss encounters '+data.audit.bossWaves.length+
      ' simulated seconds '+data.seconds);
  }
}
console.log('PASS Guardborn long-run combat invariants '+JSON.stringify(summary));
