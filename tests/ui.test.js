import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {chromium} from 'playwright';

test('redesigned arena displays live battle HP and retains keyboard focus across refreshes',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||undefined,args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.clock.install();await page.clock.pauseAt(new Date());
  const html=readFileSync('public/index.html','utf8').replace("const standalone=location.protocol==='file:';",'const standalone=true;');
  await page.route('http://ui.test/',r=>r.fulfill({contentType:'text/html',body:html}));await page.goto('http://ui.test/');
  await page.locator('#tutorials-off').check();await page.getByRole('button',{name:'Understood'}).click();
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));s.buildings.wood=1;s.gear.body=3;s.choices=[0,1,2].map(d=>({d,name:'Live crypt',mod:1,modifier:'wounded'}));s.recruits=[{cls:'Warrior',level:1,xp:0,dead:false},{cls:'Healer',level:1,xp:0,dead:false}];localStorage.setItem('gravehold',JSON.stringify(s));});
  await page.reload();await page.locator('[data-tab="Expeditions"]').click();
  const inventory=page.getByRole('button',{name:'Inventory',exact:true});await inventory.focus();await page.clock.runFor(1000);
  assert.equal(await inventory.evaluate(el=>el===document.activeElement),true);
  await page.locator('[data-action="enter:2"]').click();
  const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')).activeBattle);
  assert.equal(await page.locator('.hero-unit [role="meter"]').getAttribute('aria-valuenow'),String(before.allies[0].hp));
  assert.ok(before.allies[0].hp<before.allies[0].maxHp,'starting damage is reflected in the HP meter');
  await page.clock.runFor(1300);
  const after=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')).activeBattle);
  assert.ok(after.enemies.reduce((n,u)=>n+u.hp,0)<before.enemies.reduce((n,u)=>n+u.hp,0),'automatic attacks change actual enemy HP');
  for(const u of [...after.allies,...after.enemies]){
   const unit=page.locator(`[data-unit="${u.id}"]`);
   assert.equal(Number(await unit.getAttribute('data-hp')),u.hp);
   assert.equal(Number(await unit.locator('[role="meter"]').getAttribute('aria-valuenow')),Math.ceil(Math.max(0,u.hp)));
  }
  for(const width of [1440,1024,768,390]){
   await page.setViewportSize({width,height:900});
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,`arena fits ${width}px`);
   const hero=await page.locator('.hero-unit .unit-sprite svg').boundingBox(),troop=await page.locator('.support-unit .unit-sprite svg').first().boundingBox();
   assert.ok(hero.width>troop.width*2,'hero remains the focal combatant');
  }
  assert.deepEqual(errors,[]);
 }finally{await browser.close();}
});

test('family routes, checkpoint choices, mastery and debt-free recovery work through menus',async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||undefined,args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.clock.install();await page.clock.pauseAt(new Date());
  const html=readFileSync('public/index.html','utf8').replace("const standalone=location.protocol==='file:';",'const standalone=true;');await page.route('http://routes.test/',r=>r.fulfill({contentType:'text/html',body:html}));await page.goto('http://routes.test/');await page.locator('#tutorials-off').check();await page.getByRole('button',{name:'Understood'}).click();
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));Object.assign(s,{wood:400,stone:400,food:200,buildings:{wood:1,woodStorage:2,stoneStorage:2,foodStorage:2},workers:{wood:{xp:0}},choices:null});s.gear.weapon=100;s.gear.body=100;s.gearMastery={weapon:295};localStorage.setItem('gravehold',JSON.stringify(s));});await page.reload();
  await page.locator('[data-panel="storehouse"] > summary').click();assert.equal(await page.locator('[data-action^="storage:"]').count(),3);assert.match(await page.locator('.storage-wing').first().innerText(),/retained over 8h/);
  await page.locator('[data-tab="Expeditions"]').click();assert.equal(await page.locator('.family-yield').count(),3);assert.equal(await page.evaluate(()=>new Set(JSON.parse(localStorage.getItem('gravehold')).choices.map(c=>c.family)).size),3);
  await page.locator('[data-panel="departure-recovery"] > summary').click();assert.match(await page.locator('[data-panel="departure-recovery"]').innerText(),/25 gold \+ 15 food/);
  await page.locator('[data-action="enter:0"]').click();await page.clock.runFor(15000);assert.equal(await page.locator('.checkpoint-paths button').count(),2);
  await page.locator('[data-action="path:rich"]').click();await page.reload();assert.equal(await page.locator('[data-action="path:rich"]').getAttribute('aria-pressed'),'true');
  await page.screenshot({path:'/tmp/gravehold-connected-checkpoint.png',fullPage:true});await page.setViewportSize({width:390,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);await page.screenshot({path:'/tmp/gravehold-connected-checkpoint-mobile.png',fullPage:true});
  await page.locator('[data-action="continue"]').click();assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')).activeBattle.path),'rich');
  await page.clock.runFor(15000);await page.locator('[data-action="path:material"]').click();await page.locator('[data-action="continue"]').click();await page.clock.runFor(15000);
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')).gearMastery.weapon),300);
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));s.heroDead=true;s.gold=0;s.food=0;s.debt=0;s.interest=0;localStorage.setItem('gravehold',JSON.stringify(s));});await page.reload();await page.locator('[data-tab="Treasury"]').click();await page.locator('[data-action="recover"]').click();await page.clock.runFor(301000);
  const state=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(state.heroDead,false);assert.equal(state.debt,0);assert.deepEqual(errors,[]);
 }finally{await browser.close();}
});
