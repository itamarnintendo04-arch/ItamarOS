/* Static build checks and isolated UI smoke tests; no third-party dependencies. */
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const load=f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8');
const manifest=JSON.parse(load('updates/stable.json'));
const pwa=JSON.parse(load('manifest.webmanifest'));
const html=load('index.html');
const branding=['assets/branding/itamaros-logo.png',
 'assets/branding/itamaros-mark-512.png',
 'assets/branding/itamaros-icon-192.png',
 'assets/branding/itamaros-maskable-512.png',
 'assets/branding/itamaros-apple-touch-180.png',
 'assets/branding/itamaros-favicon-32.png',
 'assets/branding/itamaros-icon.ico',
 'desktop/assets/itamaros-icon.ico',
 'desktop-app/assets/itamaros-icon.ico',
 'native/config/includes.chroot/usr/share/pixmaps/itamaros.png',
 'native/config/includes.chroot/usr/share/icons/hicolor/512x512/apps/itamaros.png'];
for(const file of branding)assert.ok(fs.existsSync(path.join(__dirname,'..',file)),'Missing official brand asset: '+file);
assert.ok(html.includes('assets/branding/itamaros-mark-512.png'));
assert.ok(html.includes('rel="apple-touch-icon"'));
assert.ok(html.includes('assets/branding/itamaros-favicon-32.png'));
for(const icon of pwa.icons){assert.ok(fs.existsSync(path.join(__dirname,'..',icon.src.replace(/^\//,''))), 'Missing PWA icon '+icon.src)}
assert.ok(pwa.icons.some(icon=>icon.purpose==='maskable'));
const pack=JSON.parse(load('desktop/package.json')),remotePack=JSON.parse(load('desktop-app/package.json'));
assert.equal(pack.build.win.icon,'assets/itamaros-icon.ico');
assert.equal(remotePack.build.win.icon,'assets/itamaros-icon.ico');
assert.ok(load('desktop/prepare.cjs').includes('assets/branding/itamaros-mark-512.png'));

assert.equal(manifest.schemaVersion,1);
assert.match(manifest.version,/^\d+\.\d+\.\d+$/);
assert.deepEqual(manifest.components.map(x=>x.id),['itamaros-web','itamaros-player','itamaros-games']);
assert.equal(manifest.installers.length,0,'Do not advertise non-existent native installers');
assert.equal(pwa.display,'standalone');
for(const file of ['apps/player.js','apps/games.js','apps/more-games.js','apps/tv-streaming.js','apps/updates.js','sw.js','desktop-app/main.js','desktop/main.cjs','desktop/preload.cjs','desktop/prepare.cjs']){
 new vm.Script(load(file),{filename:file});
}
const inline=/<script(?:\s+[^>]*)?>([\s\S]*?)<\/script>/g;let count=0,m;
while((m=inline.exec(html))!==null){if(m[1].trim()){new vm.Script(m[1],{filename:'index-inline-'+(++count)})}}
assert.ok(count>=2,'Expected inline application initialization scripts');
for(const m of html.matchAll(/<script\s+defer\s+src="([^"]+)"/g)){
 const file=m[1].split('?')[0].replace(/^\//,'');assert.ok(fs.existsSync(path.join(__dirname,'..',file)),'Missing script '+file);
}
assert.ok(html.includes("launch('player')"));
assert.ok(html.includes("launch('games')"));
assert.ok(html.includes('data-tv-only="true"'), 'TV Streaming must be TV-only in the desktop grid');
assert.ok(html.includes("if(!tv&&n==='TV Streaming')return false"), 'TV Streaming must be hidden outside TV mode');
assert.ok(html.includes("if(!btn?.dataset.tvCompatible)return false"), 'TV search should exclude apps without TV support');
assert.ok(html.includes('data-tv-compatible="true"'), 'TV supported app flags must be present');
assert.ok(html.includes('href="/feedback.html"'), 'Feedback nav link must be visible');
assert.ok(html.includes("storeTab(\\'optional\\')"), 'Optional app store tab must be available');
assert.ok(html.includes("if(id==='streaming'&&document.body.dataset.device!=='tv')"), 'Direct launching must be blocked outside TV mode');
assert.ok(load('desktop/prepare.cjs').includes('apps/tv-streaming.js'), 'Offline desktop package should include TV streaming script');
assert.ok(load('sw.js').includes('/apps/tv-streaming.js?v=1.1.0'), 'PWA offline cache should include TV script');
const downloads=load('downloads.html');
assert.ok(!downloads.includes('role="alert"'), 'Avoid a site-wide Avast warning banner while keeping the file-specific safety notice');
assert.ok(downloads.includes('A reported antivirus detection'), 'The specific Windows EXE must retain its security warning');
assert.ok(downloads.includes('/feedback.html'), 'Downloads must link to the feedback form');
assert.ok(downloads.includes('iPhone/iPad IPA build artifacts'), 'Expose iOS developer package artifact page');
assert.ok(downloads.includes('Android / Android TV APK build artifacts'), 'Expose Android developer package artifact page');
assert.ok(downloads.includes('EXE download on hold pending security review'));
assert.ok(downloads.includes('id="android-download"'), 'Android TV section must be on the download page');
assert.ok(downloads.includes('ItamarOS-Android-1.2.0-debug.apk'), 'Downloader needs public direct APK URL');
assert.ok(downloads.includes('v1.2-android-preview'), 'APK preview release must be separate from Windows release');
assert.ok(downloads.includes('Unverified developer preview'), 'Debug APK must have honest safety notice');
assert.ok(load('.github/workflows/android-preview-release.yml').includes('gh release create'), 'APK preview publisher must attach public asset');
assert.ok(load('.github/workflows/android-preview-release.yml').includes('apksigner'), 'Validate APK signature format before preview publishing');

assert.ok(!downloads.includes("link(p,'Download Windows demo"), 'Do not offer a direct EXE download while antivirus alert is unresolved');
const publishingWorkflow=load('.github/workflows/desktop-demo.yml');
assert.ok(!publishingWorkflow.includes('gh release upload'), 'Disable auto-publish of unreviewed Windows EXE');
assert.ok(publishingWorkflow.includes('Get-FileHash'), 'Test builds should have checksums');

assert.ok(!html.includes("launch('itamio')"));
assert.ok(html.includes('auto-device-label'));
assert.ok(!html.includes('<select id="device-select"'));
assert.equal(manifest.version,'1.1.0');
assert.ok(!html.includes("launch('itamio')"));
assert.ok(!html.includes('id="device-select"'), 'Device layout must remain auto-detected');
assert.ok(html.includes("Software Updates"));
assert.ok(load('apps/updates.js').includes("const BUILD='"+manifest.version+"'"));
assert.ok(load('apps/updates.js').includes("/main/updates/stable.json"));

class Element{
 constructor(tag='div'){this.tagName=tag.toUpperCase();this.children=[];this.events={};this.dataset={};this.style={};this.attrs={};this.textContent='';this.value='';this.id='';this.volume=1;this.paused=true;this.currentTime=0;this.duration=0;this.classList={add(){},remove(){},toggle(){},contains:()=>false}}
 get childNodes(){return this.children}
 append(...nodes){this.children.push(...nodes);return this}
 replaceChildren(...nodes){this.children=[...nodes]}
 addEventListener(type,fn){this.events[type]=fn}
 setAttribute(n,v){this.attrs[n]=v}
 removeAttribute(n){delete this[n]}
 pause(){this.paused=true}
 play(){this.paused=false;return Promise.resolve()}
 load(){}
 getContext(){return {fillRect(){},beginPath(){},arc(){},fill(){}}}
 querySelector(selector){return this.querySelectorAll(selector)[0]||null}
 querySelectorAll(selector){const found=[];const visit=e=>{if(e instanceof Element){if((selector==='[data-game]'&&e.dataset.game)||(selector==='[data-mini]'&&e.dataset.mini))found.push(e);for(const n of e.children)visit(n)}};visit(this);return found}
}
function setup(){
 const content=new Element();content.id='content';
 const win=new Element();win.id='window';
 const scan=(id,node)=>{if(node.id===id)return node;for(const c of node.children)if(c instanceof Element){const result=scan(id,c);if(result)return result}return null};
 const document={createElement:tag=>new Element(tag),getElementById:id=>scan(id,content)||(id==='window'?win:null),contains:()=>true,addEventListener(){},activeElement:{tagName:'BODY'}};
 const data=new Map();
 const storage={getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)};
 const timers=new Map();let t=0;
 const setInterval=fn=>{timers.set(++t,fn);return t};
 const clearInterval=id=>timers.delete(id);
 const context={window:{},document,localStorage:storage,setInterval,clearInterval,setTimeout:setInterval,clearTimeout:clearInterval,confirm:()=>true,console,URL};
 return {content,document,data,timers,context};
}
function all(root,pred,results=[]){if(pred(root))results.push(root);for(const node of root.children||[])if(node instanceof Element)all(node,pred,results);return results}
const game=setup();vm.runInNewContext(load('apps/games.js'),game.context);
vm.runInNewContext(load('apps/more-games.js'),game.context);
assert.equal(typeof game.context.window.ItamarGames.mount,'function');
game.context.window.ItamarGames.mount();
assert.equal(all(game.content,e=>Boolean(e.dataset.mini)).length,6,'Expected six extra game tabs');
assert.equal(game.content.querySelectorAll('[data-mini]').length,6,'Extra game switcher accessible');
let saved=JSON.parse(game.data.get('itamaros-games-v1'));
assert.equal(saved.game2048.board.filter(Boolean).length,2);
const tabs=all(game.content,e=>Boolean(e.dataset.game));tabs.find(e=>e.dataset.game==='snake').events.click();
assert.ok(game.document.getElementById('snake-board'));
const start=all(game.content,e=>e.textContent==='Start / Pause')[0];assert.ok(start);
start.events.click();
saved=JSON.parse(game.data.get('itamaros-games-v1'));assert.equal(saved.snake.running,true);
const before=saved.snake.body[0].x;const tick=[...game.timers.values()][0];assert.equal(typeof tick,'function');tick();
saved=JSON.parse(game.data.get('itamaros-games-v1'));assert.equal(saved.snake.body[0].x,before+1);
tabs.find(e=>e.dataset.game==='memory').events.click();
saved=JSON.parse(game.data.get('itamaros-games-v1'));assert.equal(saved.memory.cards.length,16);
tabs.find(e=>e.dataset.game==='tictactoe').events.click();
saved=JSON.parse(game.data.get('itamaros-games-v1'));assert.equal(saved.tictactoe.board.length,9);
assert.equal(tabs.length,10,'Expected ten no-install games');
for(const extra of ['guess','reaction','rps','math','word','pattern']){
 tabs.find(e=>e.dataset.game===extra).events.click();
 assert.ok(all(game.content,e=>e.tagName==='H3').length>0,extra+' should render');
}

const player=setup();
player.context.URL={createObjectURL:()=> 'blob:mock',revokeObjectURL(){}};
player.context.Blob=class BlobMock{};
vm.runInNewContext(load('apps/player.js'),player.context);
player.context.window.ItamarPlayer.mount();
assert.equal(all(player.content,e=>e.tagName==='VIDEO').length,1);
assert.ok(all(player.content,e=>e.tagName==='BUTTON').length>=10);

const iconPaths=[...html.matchAll(/<img class="app-icon" src="(\/assets\/icons\/[a-z-]+\.svg)"/g)].map(m=>m[1]);
assert.equal(iconPaths.length,37,'Every web built-in app needs an icon');
for(const file of iconPaths)assert.ok(fs.existsSync(path.join(__dirname,'..',file)),'Missing app icon '+file);
assert.ok(!fs.existsSync(path.join(__dirname,'..','apps','itamio.js')));
assert.match(html,/Built-in apps/);
const builtins=JSON.parse(load('native/config/includes.chroot/usr/local/share/itamaros/builtins.json'));
assert.equal(builtins.uninstallAvailableInStore,false);
assert.ok(builtins.apps.includes('ItamarOS Shared Storage'));
console.log('ItamarOS v'+manifest.version+': syntax, 16 games, native/desktop launcher, Player, SVG icons and manifest checks passed.');

assert.ok(load('feedback.html').includes('https://github.com/itamarnintendo04-arch/ItamarOS/issues/new?'));
assert.ok(load('feedback.html').includes('Your issue will be <strong>public</strong>'));
const codeApp=JSON.parse(load('itamarcode/app-manifest.json'));
assert.equal(codeApp.builtIn,false);
assert.equal(codeApp.optional,true);
assert.equal(codeApp.releaseStatus,'source-only');
