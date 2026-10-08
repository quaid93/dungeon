import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {readFileSync} from 'node:fs';

test('combat breakdown, shared goals, recruit preparation and reordered recovery work in HTML menus',async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));await page.clock.install();await page.clock.pauseAt(new Date());
  const html=readFileSync('public/index.html','utf8').replace("const standalone=location.protocol==='file:';",'const standalone=true;');
  await page.route('http://connections.test/',r=>r.fulfill({contentType:'text/html',body:html}));await page.goto('http://connections.test/');
  await page.locator('#tutorials-off').check();await page.getByRole('button',{name:'Understood'}).click();
  await page.locator('[data-action="combat-score"]').click();
  assert.match(await page.locator('#combat-score').innerText(),/Base hero/);
  await page.locator('#combat-score [data-action="close"]').click();
  await page.locator('[data-tab="Recruits"]').click();await page.locator('[data-panel="hiring"] > summary').click();
  assert.match(await page.locator('[data-panel="hiring"]').innerText(),/Requires barracks/);
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));Object.assign(s,{wood:5000,stone:5000,food:5000,gold:10000,blueprints:10,items:{iron:1000,rivets:1000,leather:1000,essence:1000},buildings:{wood:1,stone:1,food:1,barracks:1,woodStorage:40,stoneStorage:40,foodStorage:40},equipmentBag:[{slot:'weapon',tier:2,upgrade:0,rarity:'rare',variant:'heavy',newFind:true}]});localStorage.setItem('gravehold',JSON.stringify(s));});
  await page.reload();await page.locator('[data-tab="Recruits"]').click();
  if(!await page.locator('[data-action="quarters"]').isVisible())await page.locator('[data-panel="hiring"] > summary').click();
  const before=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  for(let i=0;i<3;i++)await page.locator('[data-action="quarters"]').click();
  await page.locator('[data-action="recruit:Warrior"]').click();
  let s=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(before.wood-s.wood,900);assert.equal(before.stone-s.stone,750);assert.equal(before.food-s.food,800);assert.equal(before.gold-s.gold,150);
  assert.equal(s.recruits.length,1);assert.equal(s.quarters.stage,0);
  await page.locator('[data-tab="Settlement"]').click();assert.equal(await page.locator('.quarters-spaces [role="img"]').count(),3);assert.match(await page.locator('.quarters-spaces span').first().getAttribute('title'),/Occupied/);
  await page.locator('[data-tab="Loadout"]').click();await page.locator('[data-action="pin-item:0"]').click();
  assert.match(await page.locator('[data-panel="tracked-goal"]').first().innerText(),/maul/i);
  await page.locator('.new-finds [data-action="equip:0"]').click();
  s=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(s.pinnedGoal.kind,'upgrade');
  await page.locator('[data-panel="workshop"] > summary').click();
  assert.match(await page.locator('[data-panel="workshop"]').innerText(),/Inspect & improve/);
  await page.locator('[data-tab="Expeditions"]').click();
  assert.equal(await page.locator('.score-recommendation').count(),3);
  await page.locator('[data-action="inventory"]').click();
  assert.match(await page.locator('#inventory [title*="Iron upgrades"]').getAttribute('title'),/Materials focus/);
  await page.locator('#inventory [data-action="close"]').click();
  await page.evaluate(()=>{const s=JSON.parse(localStorage.getItem('gravehold'));s.heroDead=true;s.heroRevives=0;s.projects.infirmary={stage:3,until:0};s.recruits=[{name:'Aldric',cls:'Warrior',level:1,xp:0,dead:true,revives:0},{name:'Mira',cls:'Archer',level:1,xp:0,dead:true,revives:0}];localStorage.setItem('gravehold',JSON.stringify(s));});
  await page.reload();await page.locator('[data-tab="Treasury"]').click();await page.locator('[data-action="queue-fallen"]').click();
  await page.locator('[data-panel="recovery-queue"] > summary').click();
  await page.locator('[data-action="reorder:1:-1"]').click();
  s=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.deepEqual(s.recoveryQueue,[1,0]);
  await page.clock.runFor(30000);
  const gold=s.gold;await page.locator('[data-action="rush"]').click();
  s=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));
  assert.equal(s.heroDead,false);assert.equal(s.infirmaryPatient.target,1);assert.ok(gold-s.gold<=13);
  await page.reload();await page.clock.runFor(121000);
  s=await page.evaluate(()=>JSON.parse(localStorage.getItem('gravehold')));assert.equal(s.infirmaryPatient,null);assert.ok(s.recruits.every(r=>!r.dead&&r.revives===1));
  await page.setViewportSize({width:390,height:844});
  for(const tab of ['Settlement','Loadout','Recruits','Expeditions']){await page.locator(`[data-tab="${tab}"]`).click();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),tab+' stays within mobile width');}
  await page.locator('[data-action="combat-score"]').click();assert.ok(await page.locator('#combat-score').isVisible());assert.ok(await page.evaluate(()=>document.querySelector('#combat-score').getBoundingClientRect().right<=innerWidth));await page.locator('#combat-score [data-action="close"]').click();
  assert.deepEqual(errors,[]);
  await page.setViewportSize({width:1440,height:1000});await page.locator('[data-tab="Expeditions"]').click();await page.screenshot({path:'/tmp/gravehold-connected-expeditions.png',fullPage:true});
 }finally{await browser.close();}
});
