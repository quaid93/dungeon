import {test} from 'node:test';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';
import {readFileSync} from 'node:fs';
import path from 'node:path';
test('standalone mode works from one HTML without external requests',async()=>{
const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox']});
try{const page=await browser.newPage();const errors=[],requests=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.url()!=='http://standalone.test/')requests.push(r.url())});
// Managed Chromium blocks file URLs here; serve the unchanged inline assets
// with standalone mode selected to validate offline behavior.
const html=readFileSync(path.resolve('public/index.html'),'utf8').replace("const standalone=location.protocol==='file:';",'const standalone=true;');
await page.route('http://standalone.test/',r=>r.fulfill({contentType:'text/html',body:html}));await page.goto('http://standalone.test/');await page.clock.install();await page.getByRole('button',{name:'Understood'}).click();await page.getByRole('button',{name:'Gather wood',exact:true}).click();await page.clock.runFor(9000);await page.getByRole('button',{name:'Collect +12'}).click();assert.match(await page.locator('.resource').first().innerText(),/12/);await page.reload();assert.match(await page.locator('.resource').first().innerText(),/12/);await page.locator('[data-action="account"]').click();assert.match(await page.locator('#account').innerText(),/Local adventure/);assert.deepEqual(errors,[]);assert.deepEqual(requests,[]);
}finally{await browser.close()}
});
