// Code-based static UI review. NOT a Unity screenshot, build, or runtime test.
// Browser unavailable in this environment; reproduce source geometry on Canvas.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/sharp');
const {createCanvas,loadImage,GlobalFonts,Path2D}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/@napi-rs/canvas');
const source=fs.readFileSync(path.join(__dirname,'review-preview.html'),'utf8');
const start=source.indexOf('const DATA=')+11,end=source.indexOf(';\nconst paths=',start);
const D=JSON.parse(source.slice(start,end));
const colors={ink:'#0e1315',bronze:'#c4a385',paper:'#d9d6cc',moss:'#a8b89e',edge:'#455250',panel:'#131b1b',button:'#1a2427'};
GlobalFonts.registerFromPath(path.resolve(__dirname,'../../../Unity/Assets/Game/Resources/Eternal/Fonts/EternalKR-Regular.ttf'),'Eternal');
let c,ctx;
const paths={sword:'M8 15 17 4 21 3 20 7 10 17 M6 13 12 19 M8 17 4 21 M3 19 5 21',hero:'M5 20 A7 7 0 0 1 19 20 H5 M8.8 3.7 9.5 1.8 12 3.3 14.5 1.8 15.2 3.7',shield:'M12 3 20 6 19 14 16 18 12 21 8 18 5 14 4 6 12 3 M12 7 V16 M8 11 H16',bag:'M5 8 19 8 20 20 4 20 5 8 M8 8 A4 4 0 0 1 16 8 M8 12 V13 M16 12 V13 M8 14 A4 4 0 0 0 16 14',hamburger:'M3 5 H21 M3 12 H21 M3 19 H21',gem:'M6 4 18 4 22 9 12 21 2 9 6 4 M2 9 H22 M8 4 7 9 12 21 17 9 16 4',coin:'M12 7 15 12 12 17 9 12 12 7',compass:'M15.6 7.2 13.2 13.4 8.4 16.8 10.8 10.6 15.6 7.2 M10.8 10.6 13.2 13.4',journal:'M7 3 H20 V19 H7 Z M7 6 H4 V21 H17 V19 M10 8 H17 M10 12 H17 M10 16 H14',gift:'M3 9 H21 V13 H3 Z M5 13 V21 H19 V13 M12 9 V21',summon:'M11 3 13.5 9 20 11 13.5 13.5 11 20 8.5 13.5 2 11 8.5 9 11 3 M19 2 V6 M17 4 H21',growth:'M5 20 V15 H8 V20 M11 20 V11 H14 V20 M17 20 V7 H20 V20 M4 10 11 5 17 3 M13.5 2.5 H18 L17.4 6.5'};
function rect(x,y,w,h,fill,stroke=null,r=0){ctx.beginPath();ctx.roundRect(x,y,w,h,r);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1;ctx.stroke();}}
function text(s,x,y,size=14,color=colors.paper,align='left',max=0){ctx.font=size+'px Eternal';ctx.fillStyle=color;ctx.textAlign=align;ctx.textBaseline='top';if(max){while(ctx.measureText(s).width>max&&s.length>1)s=s.slice(0,-2)+'…';}ctx.fillText(s,x,y);}
function button(s,x,y,w,h=40,active=false,size=14){rect(x,y,w,h,active?colors.bronze:colors.button,active?colors.bronze:colors.edge,7);text(s,x+w/2,y+(h-size)/2-1,size,active?colors.ink:colors.paper,'center');}
function icon(k,x,y,size=24,color=colors.paper){ctx.save();ctx.translate(x,y);ctx.scale(size/24,size/24);ctx.strokeStyle=color;ctx.lineWidth=1.7;ctx.lineCap='round';ctx.lineJoin='round';if(paths[k])ctx.stroke(new Path2D(paths[k]));const circle=(x,y,r)=>{ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.stroke();};if(k==='hero')circle(12,7.5,3.5);if(k==='coin'||k==='compass')circle(12,12,9);if(k==='coin')circle(12,12,6);if(k==='gift'){circle(8.5,6,3);circle(15.5,6,3);}if(k==='settings'){circle(12,12,6);circle(12,12,2.2);for(let i=0;i<8;i++){let a=i*Math.PI/4;ctx.beginPath();ctx.moveTo(12+Math.cos(a)*7,12+Math.sin(a)*7);ctx.lineTo(12+Math.cos(a)*9.5,12+Math.sin(a)*9.5);ctx.stroke();}}ctx.restore();}
function gauge(x,y,w,h,value,color=colors.bronze){rect(x,y,w,h,'#243033');rect(x,y,w*value,h,color);}
function cover(img,x,y,w,h){let scale=Math.max(w/img.width,h/img.height),dw=img.width*scale,dh=img.height*scale;ctx.save();ctx.beginPath();ctx.rect(x,y,w,h);ctx.clip();ctx.drawImage(img,x+(w-dw)/2,y+(h-dh)/2,dw,dh);ctx.restore();}
function art(id,x,y,w,h){const a=D.actors[id],r=a.region,s=Math.min(w/r[2],h/r[3]);ctx.drawImage(a.image,r[0]*a.image.width/1024,r[1]*a.image.height/1024,r[2]*a.image.width/1024,r[3]*a.image.height/1024,x+(w-r[2]*s)/2,y+(h-r[3]*s)/2,r[2]*s,r[3]*s);}
function clip(x,y,w,h,fn){ctx.save();ctx.beginPath();ctx.rect(x,y,w,h);ctx.clip();fn();ctx.restore();}
function scrollbar(x,y,h,thumb){rect(x,y,8,h,'#182224',null,4);rect(x,y,8,thumb,'#6a7e71',null,4);}
function banner(name){rect(0,0,1600,56,'#202722');rect(0,54,1600,2,colors.bronze);text('UI 검토용 미리보기 · Unity 실행 캡처 아님',24,16,18,'#ead4b8');text(name,494,17,16,colors.paper);text('변경 소스 기준 정적 구성 · 배경/캐릭터 배치와 수치는 예시',1576,19,12,'#b5beb1','right');}
const team=D.heroes.slice(0,10);
function drawHunt(){
 rect(0,0,1600,900,colors.ink);cover(D.images.meadow,0,94,1600,656);
 const locs=team.map((h,i)=>[h.id,435+(i%3)*85+(i>5?30:0),145+Math.floor(i/3)*65,h.name.split(' ')[0],false]);
 locs.push(['fallen_werewolf',875,190,'',true],['fallen_ogre',1025,260,'',true],['fallen_lich',1110,110,'',true],['fallen_werewolf',955,405,'',true],['fallen_ogre',1140,400,'',true],['fallen_lich',785,380,'',true]);
 for(const[id,x,y,label,enemy]of locs){ctx.fillStyle='rgba(0,0,0,.25)';ctx.beginPath();ctx.ellipse(x+42,y+94+100,24,5,0,0,Math.PI*2);ctx.fill();art(id,x,y+94,enemy?96:84,enemy?110:102);if(label){ctx.save();ctx.shadowColor='#000';ctx.shadowBlur=3;text(label,x+42,y+79,11,'#f2eddd','center');ctx.restore();}gauge(x+20,y+93,44,3,.86,enemy?'#bd776b':colors.moss);}
 rect(0,0,1600,94,colors.ink,colors.edge);text('끝없는 사냥터 · 초원의 길　·　24 스테이지',20,21,22);
 let mx=1020;for(const[k,v,w]of[['coin','24,680',98],['gem','1,240',88]]){rect(mx,13,w,34,'#172124',null,8);icon(k,mx+8,19,21,k==='gem'?'#73d1d1':colors.bronze);text(v,mx+36,23,14);mx+=w+6;}
 button('편성',1231,12,64,36,false,13);button('일시정지',1300,12,96,36,false,13);button('×1',1401,12,52,36,false,13);button('관리',1458,12,62,36,false,13);
 gauge(20,54,1560,4,.62);text('다음 무리 62% · 원정대가 자동으로 사냥 중입니다',20,64,12,colors.moss);
 for(let i=0;i<4;i++)button(['×1','×1.5','×2','×3'][i],1422+i*42,106,38,38,i===0,10);
 rect(0,750,1600,150,colors.ink,colors.edge);text('자동사냥 중　·　원정대 10 / 10　·　적 6',16,758,12);text('연계 준비',1464,758,11,colors.bronze,'right');button('연계 펼치기',1482,754,104,24,false,11);
 const cw=(1572/10);team.forEach((h,i)=>{let x=16+i*cw,w=cw-4;rect(x,781,w,64,'#171f21','#405050',7);text(h.name.split(' ')[0],x+6,783,13,colors.paper,'left',w-12);art(h.id,x+6,800,42,35);text('Lv.20',x+53,801,12,colors.moss);text(i===2?'각성 준비':i%3===0?'3초':'준비',x+53,818,11,colors.bronze);gauge(x+6,837,w-12,3,[.91,.83,1,.75,.96,.86,1,.81,.92,.98][i],colors.moss);gauge(x+6,841,w-12,2,[.64,.48,1,.26,.72,.39,.68,.9,.43,.62][i]);});
 ['사냥','영웅','도전','가방','메뉴'].forEach((s,i)=>{let w=1572/5,x=17+i*w;rect(x,850,w-6,40,i===0?colors.bronze:colors.button,colors.edge,7);let ix=x+(w-6)/2-35;icon(['sword','hero','shield','bag','hamburger'][i],ix,858,23,i===0?colors.ink:colors.paper);text(s,ix+32,862,15,i===0?colors.ink:colors.paper);});
}
function windowFrame(x,w,title){rect(0,0,1600,900,'rgba(3,5,6,.76)');rect(x,86,w,708,colors.ink,'#5c675f',12);text(title,x+18,112,23);button('닫기',x+w-82,103,64,40);rect(x+18,149,w-36,1,'#41504c');}
function drawHero(){
 windowFrame(18,1564,'영웅 · 아우렐리아');text('골드 24,680　 ·　 젬 1,240',36,174,12,colors.moss);button('원정대 편성',1413,158,151,40);
 let bx=36,by=210,bh=499;rect(bx,by,178,bh,colors.panel,null,10);text('영웅 목록　15',bx+10,by+12,13);clip(bx+10,by+39,151,bh-49,()=>{D.heroes.forEach((h,i)=>{let y=by+39+i*80;rect(bx+10,y,148,74,i===0?'#303b33':colors.ink,colors.edge,7);if(i===0)rect(bx+10,y+2,3,70,colors.bronze);art(h.id,bx+15,y+6,48,62);text(h.name,bx+69,y+20,13,colors.paper,'left',83);text('Lv.20'+(i<10?' · 출전':''),bx+69,y+41,11,colors.moss);});});scrollbar(bx+160,by+39,bh-49,145);
 let ax=226,aw=936; text('SR',ax,212,25,colors.bronze);text('전열 수호자',ax,246,12,colors.moss);art('leonhardt',ax,269,aw,414);text('출전 · 1번 자리',ax+aw/2,687,13,colors.moss,'center');
 const ix=1178,iw=386;rect(ix,by,iw,bh,colors.panel,null,10);text('레온하르트 베일',ix+10,by+12,25);text('휴먼 · 성벽기사 · 탱커',ix+10,by+46,12,colors.moss);text('LEVEL　20 / 100',ix+10,by+66,15,colors.bronze);
 const tabs=['성장','스킬','장비','승급 · 돌파'];tabs.forEach((s,i)=>button(s,ix+10+i*92,by+98,88,39,i===0,i===3?11:12));
 clip(ix+10,by+147,352,294,()=>{
 [['공격력','156'],['방어력','115'],['체력','1,240']].forEach((s,i)=>{let x=ix+10+i*116;rect(x,by+147,111,64,'#182322',null,10);text(s[0],x+10,by+158,11,colors.moss);text(s[1],x+10,by+179,18);});
 text('장비 · 연구 · 진형 · 시너지 반영',ix+10,by+219,11,colors.moss);text('EXP　340 / 860 · 전투로 성장',ix+10,by+241,12,colors.moss);gauge(ix+10,by+263,340,6,.4,colors.moss);text('성장 연구　3 P 남음',ix+10,by+284,17);
 ['공격　 2 / 10　　+ 1 P','생존　 1 / 10　　+ 1 P','기능　 0 / 10　　+ 1 P'].forEach((s,i)=>button(s,ix+10,by+313+i*46,340,39,false,14));text('영웅 레벨이 3 오를 때마다 연구 포인트를 얻어요.',ix+10,by+457,12,colors.moss);
 });scrollbar(ix+368,by+147,294,209);button('배치 해제',ix+10,by+450,366,40);
 text('원정대',36,735,12,colors.moss);text('10 / 10',36,754,12,colors.moss);team.forEach((h,i)=>{let x=93+i*49;rect(x,724,44,48,i===0?colors.bronze:colors.ink,colors.edge,7);art(h.id,x+3,728,38,40);});
}
function feature(x,y,w,h,id,title,subtitle,picture=null,disabled=false){ctx.save();if(disabled)ctx.globalAlpha=.53;rect(x,y,w,h,'#121d26','#425763',5);if(picture)cover(D.images[picture],x+1,y+1,w-2,h-2);else icon(id==='war'||id==='raid'?'sword':id,x+(w-54)/2,y+(id==='war'?46:5),54,colors.bronze);let ch=59;rect(x+1,y+h-ch,w-2,ch-1,'rgba(6,14,20,.88)');text(title,x+w/2,y+h-ch+8,19,colors.paper,'center');text(subtitle,x+w/2,y+h-ch+34,12,disabled?colors.bronze:colors.moss,'center');ctx.restore();}
function drawMenu(){
 const x=682,w=900;windowFrame(x,w,'전체 메뉴');ctx.globalAlpha=.45;icon('journal',x+w-186,109,28);ctx.globalAlpha=1;icon('gift',x+w-138,109,28);
 const fx=x+18,fy=176,fw=850,warw=fw*.18,rw=fw-warw-10;feature(fx,fy,warw,250,'war','종의 전쟁','전쟁 기능 이관 중',null,true);let rx=fx+warw+10;
 feature(rx,fy,(rw-10)/2,120,'camp','원정 캠프','모험의 시작','camp');feature(rx+(rw-10)/2+10,fy,(rw-10)/2,120,'world','사냥터','지역과 보상','world');let tw=(rw-20)/3;feature(rx,fy+130,tw,120,'summon','소환','영웅과 수호령');feature(rx+tw+10,fy+130,tw,120,'raid','레이드','보스 토벌','raid');feature(rx+2*(tw+10),fy+130,tw,120,'growth','성장 · 던전','도전과 성장');
 const links=[['가방','bag'],['영웅','hero'],['파티 편성','hero'],['전투 진형','shield'],['영웅 도감','journal'],['성장 연구','growth'],['보상 센터','gift'],['목표 · 업적','journal',true],['거래소','coin',true],['진영 선택','sword'],['가이드','compass'],['설정','settings']];links.forEach((a,i)=>{let cx=fx+(i%6+.5)*(fw/6),y=442+Math.floor(i/6)*92;ctx.save();if(a[2])ctx.globalAlpha=.46;icon(a[1],cx-16,y+8,32);text(a[0],cx,y+47,14,colors.paper,'center');if(a[2])text('이관 중',cx,y+68,10,colors.bronze,'center');ctx.restore();});
 rect(fx,712,864,1,'rgba(64,87,99,.7)');for(const[s,tx]of[['스킬 효과 ON',fx],['효과음 ON',fx+140]]){rect(tx,742,15,15,colors.bronze,null,2);text('✓',tx+7.5,741,12,colors.ink,'center');text(s,tx+22,742,14);}button('시작 화면',1462,731,102,42);
}
(async()=>{
 for(const a of Object.values(D.actors))a.image=await loadImage(await sharp(Buffer.from(a.uri.split(',')[1],'base64')).png().toBuffer());
 for(const k of Object.keys(D.images))D.images[k]=await loadImage(await sharp(Buffer.from(D.images[k].split(',')[1],'base64')).png().toBuffer());
 const records=[];
 for(const[view,name,title]of[['hunt','01-hunt-hud-review.png','01 · 사냥 HUD'],['hero','02-hero-showcase-review.png','02 · 영웅 관리'],['menu','03-full-menu-review.png','03 · 전체 메뉴']]){
  c=createCanvas(1600,956);ctx=c.getContext('2d');ctx.imageSmoothingEnabled=true;banner(title);ctx.save();ctx.translate(0,56);drawHunt();if(view==='hero')drawHero();if(view==='menu')drawMenu();ctx.restore();fs.writeFileSync(path.join(__dirname,name),await sharp(await c.encode('png')).removeAlpha().png({compressionLevel:9}).toBuffer());records.push({view,file:name,pixels:[1600,956],renderer:'@napi-rs/canvas',unity_execution:false,disclosure:'UI 검토용 미리보기 · Unity 실행 캡처 아님'});
 }
 fs.writeFileSync(path.join(__dirname,'preview-render-check.json'),JSON.stringify({browser_unavailable:'No local Chromium; download returned Site Unavailable HTML',method:'Static Canvas UI recreation using source dimensions and original atlas sprite rectangles. Not an engine screenshot or functional test.',images:records},null,2));console.log(JSON.stringify(records));
})();
