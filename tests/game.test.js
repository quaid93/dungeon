import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {chromium} from 'playwright';
import {tmpdir} from 'node:os';
import path from 'node:path';
test('settlement, dungeon, crafting, debt, and account sync',async()=>{
const dir=await mkdtemp(path.join(tmpdir(),'gravehold-test-'));const server=spawn(process.execPath,['server.js'],{env:{...process.env,PORT:'3019',DATA_DIR:dir}});
await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);server.once('exit',c=>reject(new Error('Server exited '+c)))});
let browser;try{
browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox']});
const context=await browser.newContext();const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('http://localhost:3019',{waitUntil:'domcontentloaded'});await page.clock.install();
assert.equal(await page.locator('#journal').evaluate(d=>d.open),true);await page.getByRole('button',{name:'Understood'}).click();
await page.getByRole('button',{name:'Gather wood',exact:true}).click();await page.clock.runFor(9000);await page.getByRole('button',{name:'Collect +12'}).click();assert.match(await page.locator('.resource').first().innerText(),/12/);
await page.evaluate(()=>{let s=JSON.parse(localStorage.getItem('gravehold'));s.wood=100;s.stone=100;s.food=100;s.gold=500;s.items={iron:50,rivets:50};s.blueprints=10;localStorage.setItem('gravehold',JSON.stringify(s))});await page.reload({waitUntil:'domcontentloaded'});
await page.locator('[data-action="build:wood"]').click();await page.locator('[data-action="worker:wood"]').click();await page.locator('[data-tab="Loadout"]').click();await page.getByRole('button',{name:'Understood'}).click();await page.locator('[data-action="craft:weapon"]').click();await page.locator('[data-action="upgrade:weapon"]').click();
let state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(state.gear.weapon,1);assert.equal(state.gearUpgrades.weapon,1);assert.equal(state.blueprints,9);
await page.evaluate(()=>{let s=JSON.parse(localStorage.getItem('gravehold'));s.gear.weapon=10;s.gear.armor=10;localStorage.setItem('gravehold',JSON.stringify(s))});await page.reload({waitUntil:'domcontentloaded'});
await page.locator('[data-tab="Expeditions"]').click();await page.getByRole('button',{name:'Understood'}).click();assert.equal(await page.locator('[data-action^="enter:"]').count(),3);await page.locator('[data-action="enter:0"]').click();await page.clock.runFor(12500);await page.locator('[data-action="extract"]').click();state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(state.expeditions,1);assert.equal(state.activeBattle,null);
await page.evaluate(()=>{let s=JSON.parse(localStorage.getItem('gravehold'));s.heroDead=true;s.gold=0;s.food=0;localStorage.setItem('gravehold',JSON.stringify(s))});await page.reload({waitUntil:'domcontentloaded'});await page.locator('[data-tab="Treasury"]').click();await page.getByRole('button',{name:'Understood'}).click();await page.locator('[data-action="loan"]').click();state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(state.debt,55);assert.equal(state.heroDead,false);
await page.locator('[data-action="account"]').click();await page.locator('#email').fill('player@example.com');await page.locator('#password').fill('secure-test-password');await page.locator('[data-action="register"]').click();await page.waitForFunction(()=>!document.querySelector('#account').open);await page.clock.runFor(1000);
const other=await browser.newContext();const second=await other.newPage();await second.goto('http://localhost:3019',{waitUntil:'domcontentloaded'});await second.getByRole('button',{name:'Understood'}).click();await second.locator('[data-action="account"]').click();await second.locator('#email').fill('player@example.com');await second.locator('#password').fill('secure-test-password');await second.locator('[data-action="login"]').click();await second.waitForFunction(()=>!document.querySelector('#account').open);const saved=await second.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(saved.debt,55);
assert.deepEqual(errors,[]);await page.screenshot({path:'/tmp/gravehold-tested.png',fullPage:true});
}finally{if(browser)await browser.close();server.kill();await new Promise(resolve=>server.once('exit',resolve));await rm(dir,{recursive:true,force:true})}
});
