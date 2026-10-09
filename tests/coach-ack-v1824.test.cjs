'use strict';
// First-session hints must not be permanently suppressed before user approval.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
assert.equal(scripts(pc)[1],scripts(mobile)[1],'PC/mobile game JavaScript diverged');
const begin='  class Game {',end="\n\n  window.addEventListener('DOMContentLoaded'";
const i=pc.indexOf(begin),j=pc.indexOf(end,i);
assert(i>=0&&j>i,'Missing Game class');
const elements=new Map();
function $(id){
  if(!elements.has(id)){
    const classes=new Set(id==='coachScreen'?['hidden']:[]);
    elements.set(id,{textContent:'',classList:{
      add:name=>classes.add(name),remove:name=>classes.delete(name),
      contains:name=>classes.has(name)}});
  }
  return elements.get(id);
}
const Game=new Function('$','return ('+pc.slice(i,j).trim()+')')($);
function fixture(save){
  let saves=0;
  const g=Object.create(Game.prototype);
  g.save=save;g.lang='ru';g.persist=()=>saves++;
  g.track=()=>{};
  g.coachData=()=>({icon:'◎',kicker:'ТЕСТ',title:'Ресурсы',text:'Пояснение',tip:'Совет'});
  return {g,count:()=>saves};
}
const save={coachSeen:{}};
const first=fixture(save);
assert.equal(first.g.showCoach('resources'),true);
assert.equal($('coachScreen').classList.contains('hidden'),false);
assert.equal(save.coachSeen.resources,undefined,'Opening should not complete the coach');
assert.equal(first.count(),0,'Opening should not persist acknowledged flag');
assert.equal(first.g.showCoach('fragments'),false,'Do not replace an unacknowledged tip');
// Simulate tab close/reload before tapping the confirmation button.
elements.clear();
const next=fixture(JSON.parse(JSON.stringify(save)));
assert.equal(next.g.showCoach('resources'),true,'Tip lost after abandoning it');
assert.equal(next.g.showCoach('contract'),false);
next.g.closeCoach();
assert.equal($('coachScreen').classList.contains('hidden'),true);
assert.equal(next.g.save.coachSeen.resources,true,'Continue must acknowledge tip');
assert.equal(next.count(),1,'Acknowledgement must be saved exactly once');
next.g.closeCoach();
assert.equal(next.count(),1,'Repeated closing must not resave');
assert.equal(next.g.showCoach('resources'),false,'Acknowledged tip must not recur');
assert.equal(next.g.showCoach('fragments'),true,'Next unlocked tip should still open');
console.log('PASS first-session coach acknowledgement/reload, no early suppression, script parity');
