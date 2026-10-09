'use strict';
// Regression against the actual Game.labUpgradeCost / Game.buyLab methods.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const read=dir=>fs.readFileSync(path.join(__dirname,'..',dir,'index.html'),'utf8');
const pc=read('pc'),mobile=read('iphone');
const scripts=s=>[...s.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const a=scripts(pc),b=scripts(mobile);
assert.equal(a[1],b[1],'PC/mobile Lab code diverged');
const hook="window.addEventListener('DOMContentLoaded',()=>{ const game=new Game(); window.__ENDLESS_DEFENDERS__=game; game.init(); });";
assert(a[1].includes(hook),'Game regression hook missing');
const win={};
new Function('window','document','navigator','performance',
 a[0]+'\n'+a[1].replace(hook,'window.__labTest={Game,LABS,DEFAULT_SAVE,BALANCE,TEXT};')
)(win,{}, {language:'ru'},{now:()=>0});
const {Game,LABS,DEFAULT_SAVE,BALANCE,TEXT}=win.__labTest;
const names=['damage','core','income','start'];
const price=(k,l)=>Object.create(Game.prototype).labUpgradeCost(k,l);
let passed=0;function check(name,fn){fn();passed++;console.log('PASS '+name);}
function fixture(){
 const g=Object.create(Game.prototype);g.save=JSON.parse(JSON.stringify(DEFAULT_SAVE));
 g.lang='ru';g.t=TEXT.ru;g.audio={upgrade(){}};
 const events=[];
 g.track=name=>events.push(name);g.persist=()=>{};g.renderHome=()=>{};
 return {g,events};
}
check('Displayed shard-income bonus matches actual +4% run and offline math',()=>{
 assert.equal(BALANCE.economy.runShardPerWave,3);
 assert(pc.includes("labIncomeDesc:'+4% осколков после вылазки.'"));
 assert(pc.includes("labIncomeDesc:'+4% shards after each run.'"));
 assert(mobile.includes("labIncomeDesc:'+4% осколков после вылазки.'"));
 assert(mobile.includes("labIncomeDesc:'+4% shards after each run.'"));
 assert(!pc.includes("labIncomeDesc:'+7%"));
 assert(!mobile.includes("labIncomeDesc:'+7%"));
 assert(pc.includes("this.save.lab.income*.04")&&mobile.includes("this.save.lab.income*.04"));
});
check('Base Lab costs and 8-level pivot are preserved',()=>{
 for(const [k,[base,growth]] of Object.entries({damage:[55,1.55],core:[50,1.52],income:[75,1.62],start:[45,1.5]})){
  assert.equal(price(k,0),base);
  for(let i=0;i<=8;i++)assert.equal(price(k,i),Math.floor(base*Math.pow(growth,i)));
  for(let i=9;i<LABS[k].max;i++)assert(price(k,i)>price(k,i-1));
 }
});
check('Unaffordable and unknown Lab purchases never modify progress',()=>{
 const {g}=fixture(),start=JSON.stringify(g.save);
 g.buyLab('damage');g.buyLab('nonexistent');
 assert.equal(JSON.stringify(g.save),start);
});
check('Each purchase charges the current live cost exactly once',()=>{
 const {g,events}=fixture();
 g.save.shards=price('damage',0);
 const first=g.save.shards;g.buyLab('damage');
 assert.equal(g.save.shards,first-price('damage',0));assert.equal(g.save.lab.damage,1);
 g.buyLab('damage');assert.equal(g.save.shards,0);assert.equal(g.save.lab.damage,1);
 assert.deepEqual(events,['first_lab_upgrade']);
});
check('All four Lab paths charge exact prices through the late pivot',()=>{
 for(const key of names){
  const {g,events}=fixture();let spent=0;
  for(let level=0;level<=10;level++){
   const c=g.labUpgradeCost(key);g.save.shards+=c;spent+=c;
   g.buyLab(key);
   assert.equal(g.save.lab[key],level+1,key+' level wrong');
   assert.equal(g.save.shards,0,key+' charged incorrectly');
  }
  assert.equal(spent,Array.from({length:11},(_,i)=>price(key,i)).reduce((a,b)=>a+b,0));
  assert.equal(events.filter(e=>e==='first_lab_upgrade').length,1);
 }
});
check('All four Lab caps prevent excess currency spending',()=>{
 for(const key of names){
  const {g}=fixture();g.save.lab[key]=LABS[key].max;g.save.shards=1000000;
  g.buyLab(key);g.buyLab(key);
  assert.equal(g.save.lab[key],LABS[key].max);assert.equal(g.save.shards,1000000);
 }
});
check('Damage Lab helps range but remains capped',()=>{
 const {g}=fixture();const baseline=g.masteryBonuses('sentinel');
 g.save.lab.damage=10;
 const improved=g.masteryBonuses('sentinel');
 assert(improved.range>baseline.range);
 g.save.lab.damage=LABS.damage.max;
 const max=g.masteryBonuses('sentinel');
 assert(max.range<=1+BALANCE.economy.defenderRangeBonusCap+1e-9);
});
check('Old save normalization preserves bought Labs and spendable currencies',()=>{
 const {g}=fixture();g.save.lab={damage:9,core:7,income:5,start:6};
 g.save.shards=12345;g.save.gems=77;
 const restored=g.normalizeSave({...g.save,version:20});
 assert.deepEqual(restored.lab,g.save.lab);
 assert.equal(restored.shards,12345);assert.equal(restored.gems,77);
 assert.equal(restored.version,21);assert(pc.includes('out.version=21')&&mobile.includes('out.version=21'));
});
console.log(passed+' Lab spending guard groups passed');
