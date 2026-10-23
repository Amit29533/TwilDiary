import {fileURLToPath} from 'node:url';
import {referenceBrowser,settle} from './browser.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const output = new URL('../docs/reference/chromium-win32-402x778/',import.meta.url);
await mkdir(output,{recursive:true});
for (const [name,path] of [['home','/preview/home'],['library','/preview/library'],['glance','/preview'],['stats-month','/preview/activity'],['title-show','/preview/title/again']]) {
 const {browser,page,origin}=await referenceBrowser('default',{viewport:{width:402,height:778}});
 await page.goto(origin+path);await settle(page);
 await page.screenshot({path:fileURLToPath(new URL(name+'.png',output)),animations:'disabled'});
 await browser.close();
}
await writeFile(new URL('README.md',output),'Secondary web references at 402x778, matching iPhone 17 Pro usable content after documented 62pt top/34pt bottom OS insets. Primary 390x844 references remain unchanged. Chromium/Windows typography differs from iOS; these are comparison inputs, not a pixel-parity claim.\n');
