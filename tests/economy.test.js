import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
function game(){const context=vm.createContext({location:{protocol:'http:'},localStorage:{getItem:()=>null,setItem:()=>{}},document:{addEventListener:()=>{}},Date,Math,JSON,fetch:()=>Promise.resolve({}),console});const source=readFileSync('public/index.html','utf8').match(/<script type="module">([\s\S]*?)<\/script>/)[1].split('setInterval(()=>')[0];vm.runInContext(source,context);vm.runInContext('render=()=>{}',context);return code=>vm.runInContext(code,context)}
test('offline earnings run at half rate and respect capacity',()=>{const run=game();run('s.workers.wood={xp:0};s.last=Date.now()-60000;accrue()');assert.ok(Math.abs(run('s.wood')-30)<.1);run('s.last=Date.now()-3600000;accrue()');assert.equal(run('s.wood'),100)});
test('loan interest applies every five expeditions without compounding',()=>{const run=game();run('s.debt=100;s.interest=10');for(let i=0;i<5;i++)run('battle={loot:{gold:0,wood:0,stone:0,food:0,iron:0,rivets:0,blueprints:0}};finish(true)');assert.equal(run('s.interest'),11);assert.equal(run('s.debt'),100);assert.equal(run('s.loanRuns'),0)});
test('free recovery completes after its deadline',()=>{const run=game();run('s.heroDead=true;s.recover=Date.now()+300000;accrue()');assert.equal(run('s.heroDead'),true);run('s.recover=Date.now()-1;accrue()');assert.equal(run('s.heroDead'),false);assert.equal(run('s.recover'),0)});
