'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const pc=fs.readFileSync(path.join(__dirname,'..','pc','index.html'),'utf8');
const mobile=fs.readFileSync(path.join(__dirname,'..','iphone','index.html'),'utf8');
const chunks=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const a=chunks(pc),b=chunks(mobile);
assert.equal(a[1],b[1],'PC and mobile gameplay scripts diverged');
const win={};const source=a[1].replace(
 "window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });",
 "window.__test={Game,TEXT,DEFAULT_SAVE,DEFENDER_CONTRACTS};");
assert(source.includes('window.__test={Game'),'Missing test entrypoint');
new Function('window','document','navigator','performance',a[0]+'\n'+source)(win,{}, {language:'ru'},{now:()=>0});
const {Game,TEXT,DEFAULT_SAVE}=win.__test;
const game=Object.create(Game.prototype);
game.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));game.lang='ru';game.t=TEXT.ru;
let count=0;
function test(name,fn){assert(fn(),name);count++;console.log('PASS '+name)}
test('Starts with Prism as the persistent contract goal',()=>{const g=game.contractGoalData();return g.id==='prism'&&g.wave[1]===40&&g.parts[1]===2&&g.shards[1]===2500&&g.gems[1]===18});
test('Shows four separate resource progress meters',()=>{const html=game.renderContractGoal();return html.includes('data-contract-goal="prism"')&&(html.match(/class="contract-goal-meter"/g)||[]).length===4});
test('Keeps next boss and costs visible without giving resources',()=>{const before=JSON.stringify(game.save),html=game.renderContractGoal();return html.includes('40')&&html.includes('2')&&JSON.stringify(game.save)===before});
test('Goal follows unlocked sequence',()=>{game.save.unlocked.push('prism');let a=game.contractGoalData();game.save.unlocked.push('nova');let b=game.contractGoalData();return a.id==='nova'&&a.nextWave===50&&b.id==='ember'&&b.nextWave===60});
test('Progress caps visually without changing balances',()=>{game.save.unlocked=['sentinel','spark','frost'];game.save.bestWave=200;game.save.shards=999999;game.save.gems=500;game.save.defenderParts.prism=3;const goal=game.contractGoalData(),html=game.renderContractGoal();return goal.wave[0]===40&&goal.shards[0]===2500&&goal.gems[0]===18&&goal.parts[0]===2&&goal.ready&&html.includes('собери защитника')&&game.save.shards===999999});
test('Ready goal does not bypass activation',()=>!game.save.unlocked.includes('prism'));
test('All defenders unlocked removes the goal',()=>{game.save.unlocked=['sentinel','spark','frost','prism','nova','ember','volt','chrono'];return game.contractGoalData()===null&&game.renderContractGoal()===''});
test('No changes to persistence schema',()=>pc.includes('out.version=21')&&mobile.includes('out.version=21'));
test('Both builds carry the same v1.8.24 version',()=>pc.includes("version: '1.8.24'")&&mobile.includes("version: '1.8.24'"));
console.log(count+' progression UI tests passed');
