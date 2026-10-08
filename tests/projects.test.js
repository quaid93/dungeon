import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {readFileSync} from 'node:fs';

test('HTML infirmary phases, free timed revivals, and weapon identities work through menus',async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.clock.install();
  const html=readFileSync('public/index.html','utf8').replace("const standalone=location.protocol==='file:';",'const standalone=true;');
  await page.route('http://projects.test/',route=>route.fulfill({contentType:'text/html',body:html}));
  await page.goto('http://projects.test/');
  await page.locator('#tutorials-off').check();
  await page.getByRole('button',{name:'Understood'}).click();
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));Object.assign(s,{wood:2500,stone:2500,food:2500,gold:10000,items:{iron:1000,rivets:1000,leather:1000,essence:1000},blueprints:20,buildings:{wood:1,barracks:1,woodStorage:20,stoneStorage:20,foodStorage:20},recruits:[{name:'Aldric',cls:'Warrior',level:1,xp:0,dead:true}],equipmentBag:[{slot:'weapon',tier:1,upgrade:0,rarity:'rare',variant:'heavy',newFind:true},{slot:'weapon',tier:1,upgrade:0,rarity:'rare',variant:'swift',newFind:true}]});localStorage.setItem('gravehold',JSON.stringify(s));});
  await page.reload();
  await page.locator('[data-panel="settlement-projects"] > summary').click();
  for(const seconds of [60,120,180]){
   await page.locator('[data-action="project:infirmary"]').click();
   assert.match(await page.locator('[data-panel="settlement-projects"]').innerText(),/Construction/);
   await page.clock.runFor((seconds+1)*1000);
  }
  assert.match(await page.locator('[data-panel="settlement-projects"]').innerText(),/Fully restored/);
  await page.screenshot({path:'/tmp/gravehold-html-infirmary.png',fullPage:true});
  await page.locator('[data-tab="Recruits"]').click();
  await page.locator('[data-action="infirmary:0"]').click();
  await page.locator('[data-tab="Expeditions"]').click();
  assert.equal(await page.locator('[data-action^="enter:"]:disabled').count(),3);
  const funds=await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));return [s.gold,s.food]});
  await page.clock.runFor(61000);
  let state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(state.recruits[0].dead,false);
  assert.equal(state.recruits[0].revives,1);
  assert.deepEqual([state.gold,state.food],funds);
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));s.heroDead=true;localStorage.setItem('gravehold',JSON.stringify(s));});
  await page.reload();
  await page.locator('[data-tab="Treasury"]').click();
  await page.locator('[data-action="infirmary:hero"]').click();
  await page.reload();
  await page.clock.runFor(61000);
  state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(state.heroDead,false);
  assert.equal(state.infirmaryPatient,null);
  await page.locator('[data-tab="Loadout"]').click();
  await page.locator('[data-action="equip:0"]').first().click();
  state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(state.gearVariants.weapon,'heavy');
  await page.locator('.equipment-slot[data-action="slot:weapon"]').click();
  assert.match(await page.locator('.slot-options').innerText(),/60% attack speed/);
  await page.locator('.slot-options [data-action="equip:0"]').click();
  await page.locator('[data-action="upgrade:weapon"]').click();
  await page.locator('[data-action="craft:weapon"]').click();
  state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(state.gearVariants.weapon,'swift');
  assert.equal(state.gear.weapon,2);
  assert.equal(state.equipmentBag[0].variant,'heavy');
  assert.match(await page.locator('.selected-item').innerText(),/Gravewarden dirk/i);
  await page.locator('[data-panel="weapon-pool"] > summary').click();
  assert.equal(await page.locator('[data-panel="weapon-pool"] .inventory-item').count(),6);
  await page.screenshot({path:'/tmp/gravehold-html-weapon-pool.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.locator('[data-tab="Settlement"]').click();
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  assert.deepEqual(errors,[]);
 }finally{await browser.close();}
});
