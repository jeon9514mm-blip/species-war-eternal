// Source-aligned review render only: this does not launch or validate Unity.
const { chromium } = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES + '/playwright');
const path = require('path');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
  const page = await browser.newPage({ viewport:{width:1600,height:956}, deviceScaleFactor:1 });
  const records=[];
  for(const [view,name] of [['hunt','01-hunt-hud-review.png'],['hero','02-hero-showcase-review.png'],['menu','03-full-menu-review.png']]) {
    await page.goto('file://'+path.join(__dirname,'review-preview.html')+'?view='+view);
    await page.waitForFunction(()=>window.previewReady);
    await page.evaluate(()=>document.fonts.ready);
    if(view==='hero')await page.evaluate(()=>{const p=document.querySelector('.main-portrait');p.innerHTML=art('leonhardt',p.clientWidth,p.clientHeight);});
    await page.screenshot({path:path.join(__dirname,name)});
    records.push({view,file:name,title:await page.title(),overflow:await page.evaluate(()=>({body:document.body.scrollWidth,viewport:innerWidth})),unity_execution:false});
  }
  fs.writeFileSync(path.join(__dirname,'preview-render-check.json'),JSON.stringify(records,null,2));
  await browser.close();
  console.log(JSON.stringify(records));
})();
