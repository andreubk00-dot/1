'use strict';
// Run-finalization telemetry must count one depth per run, even after a rewarded revive.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
assert.equal(scripts(pc)[1],scripts(mobile)[1],'PC/mobile game scripts diverged');
const i=pc.indexOf('  class Game {'),j=pc.indexOf("\n\n  window.addEventListener('DOMContentLoaded'",i);
assert(i>=0&&j>i,'Missing Game class');
const elements=new Map();
function $(id){if(!elements.has(id))elements.set(id,{classList:{add:()=>{},remove:()=>{}}});return elements.get(id);}
let clock=2000000,persists=0;
const Game=new Function('$','now','document','return ('+pc.slice(i,j).trim()+')')($,()=>clock,{dispatchEvent:()=>{}});
const g=Object.create(Game.prototype);
g.save={runs:1,sound:false,analytics:{events:{},waves:{},recent:[]}};
g.challenge=false;g.run={wave:5,reached:5,completed:4,startedAt:clock-18000,manualEnd:false,revived:false,firstRun:true,manualHits:3,weakHits:1};
g.resultAdBusy=false;g.bridge={adInProgress:false};g.canShowInterstitial=()=>false;
g.persist=()=>{persists++;};g.renderHome=()=>{};g.showScreen=()=>{};g.audio={startMenuMusic:()=>{}};
g.track('boss_kill',{wave:5});g.track('wave_milestone',{wave:5});
g.track('reward_ad_offer',{wave:5,placement:'revive'});
assert.deepEqual(g.save.analytics.waves,{},'Unrelated events polluted the depth histogram');
// First result is not a finished run if the player chooses to revive.
g.track('run_result',g.runOutcomeMeta(g.run));
g.run.revived=true;g.run.wave=10;g.run.reached=10;g.run.completed=9;
g.track('run_result',g.runOutcomeMeta(g.run));
assert.equal(g.save.analytics.events.run_result,2);
assert.equal(g.save.analytics.events.run_finish||0,0);
assert.deepEqual(g.save.analytics.waves,{});
(async()=>{
  await g.leaveResult();
  assert.equal(g.save.analytics.events.run_finish,1,'Revived run finalized more than once');
  assert.deepEqual(g.save.analytics.waves,{'10':1},'Incorrect final depth');
  assert.equal(g.save.analytics.events.run_end_defeat,1);
  const end=g.save.analytics.recent.at(-1);
  assert.equal(end.event,'run_finish');assert.equal(end.meta.revived,true);
  assert.equal(end.meta.reason,'defeat');assert.equal(end.meta.firstRun,true);
  assert.equal(end.meta.completed,9);assert.equal(end.meta.durationMs,18000);
  assert.equal(g.run,null);assert.equal(persists,1,'Final telemetry not persisted');
  await g.leaveResult();assert.equal(g.save.analytics.events.run_finish,1,'Duplicate leave tracked again');
  g.save.runs=2;g.run={wave:1,reached:1,completed:0,startedAt:clock-5000,manualEnd:true,firstRun:false};
  await g.leaveResult();
  assert.equal(g.save.analytics.events.run_end_manual,1);
  assert.deepEqual(g.save.analytics.waves,{'1':1,'10':1});
  const summary=g.analyticsSummary();
  assert.equal(summary.runs.manual,1);assert.equal(summary.runs.defeats,1);
  assert.equal(summary.runs.results,2);
  assert.equal(summary.runs.finished,2);
  console.log('PASS final run depths, revived run dedupe, exit reasons, summary and PC/mobile parity');
})().catch(e=>{console.error(e);process.exitCode=1;});
