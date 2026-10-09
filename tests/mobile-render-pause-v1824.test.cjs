'use strict';
// Ensure pausing, backgrounding and platform overlays do not waste mobile
// frames, while the foreground combat canvas and its FPS sampler recover.
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)].map(x=>x[1]);
assert.equal(scripts(pc)[1],scripts(mobile)[1],'PC/mobile game JavaScript diverged');
const begin='  class Game {';
const end="\\n\\n  window.addEventListener('DOMContentLoaded'";
function extract(src){
  const i=src.indexOf(begin),j=src.indexOf('\n\n  window.addEventListener(\'DOMContentLoaded\'',i);
  assert(i>=0&&j>i,'Cannot isolate Game class');
  return src.slice(i,j);
}
const doc={hidden:false};
let battleHidden=false,scheduled=0;
const $=()=>({classList:{contains:()=>battleHidden}});
const Game=new Function('document','$','requestAnimationFrame',
  'return ('+extract(pc).trim()+')')(doc,$,()=>{scheduled++;return scheduled;});
const g=Object.create(Game.prototype);
let drawn=0,advanced=0,sampled=0;
g.lastFrame=100;
g.paused=false;g.externalPause=false;g.inRun=true;
g.stepCombat=()=>{advanced++;};g.draw=()=>{drawn++;};
g.samplePerformance=()=>{sampled++;};
const check=(timestamp,expectedDraw)=>{
  g.loop(timestamp);
  assert.equal(drawn,expectedDraw,'Unexpected canvas draw');
};
check(116,1);
doc.hidden=true;check(132,1); // browser tab backgrounded
doc.hidden=false;g.paused=true;check(148,1); // gameplay paused
g.paused=false;g.externalPause=true;check(164,1); // SDK or ad paused
g.externalPause=false;battleHidden=true;check(180,1); // not in battle UI
battleHidden=false;check(196,2); // drawing resumes after foregrounding
assert.equal(advanced,6,'Frame scheduling or game clock changed');
assert.equal(sampled,6,'FPS monitoring should stay scheduled');
assert.equal(scheduled,6,'Animation loop must not terminate on background/paused frames');
assert.equal(g.lastFrame,196);
console.log('PASS paused/background canvas draw guard and PC/mobile script parity');
