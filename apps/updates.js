/* ItamarOS Software Updates: browser-only manifest/reload flow.
 * Native OS/application installation is intentionally NOT implemented here. */
(()=>{
'use strict';
const REPO='itamarnintendo04-arch/ItamarOS';
const BUILD='1.1.0';
const MANIFEST='https://raw.githubusercontent.com/'+REPO+'/main/updates/stable.json';
const MAX_NOTES=8;
let latest=null,lastCheck=0,lastError='',installedPrompt=null,checking=null;
const id=s=>document.getElementById(s);
const version=v=>String(v||'').split('.').slice(0,3).map(part=>Number(part.replace(/[^0-9].*$/,''))||0);
function compare(a,b){const x=version(a),y=version(b);for(let i=0;i<3;i++){if(x[i]!==y[i])return x[i]>y[i]?1:-1}return 0}
function saved(){try{return JSON.parse(localStorage.getItem('itamaros-update-preferences')||'{}')}catch{return {}}}
function save(p){localStorage.setItem('itamaros-update-preferences',JSON.stringify({...saved(),...p}))}
function el(tag,txt,cls){const e=document.createElement(tag);if(txt!==undefined)e.textContent=txt;if(cls)e.className=cls;return e}
function button(txt,fn){const b=el('button',txt);b.type='button';b.addEventListener('click',fn);return b}
function officialURL(v){try{const u=new URL(v);return u.protocol==='https:'&&u.hostname==='github.com'&&u.pathname.startsWith('/'+REPO+'/releases/download/')}catch{return false}}
function validManifest(m){return m&&m.schemaVersion===1&&/^\d+\.\d+\.\d+$/.test(m.version)&&Array.isArray(m.components)&&m.components.every(c=>c&&typeof c.id==='string'&&/^\d+\.\d+\.\d+$/.test(c.version)&&['web'].includes(c.platform)&&['reload','bundled'].includes(c.delivery))}
function newAvailable(){return latest&&compare(latest.version,BUILD)>0}
function localDesktopDemo(){return window.ItamarRuntime?.edition==='desktop-demo'||location.hostname==='127.0.0.1'}
function showToast(force=false){if(!newAvailable())return;const p=saved();if(!force&&p.deferVersion===latest.version&&Date.now()<(p.deferUntil||0))return;let root=id('ios-update-toast');if(!root){root=el('section');root.id='ios-update-toast';root.setAttribute('role','status');document.body.append(root)}root.replaceChildren();root.append(el('strong','ItamarOS update available: '+latest.version));root.append(el('p',localDesktopDemo()?'A newer version exists. This desktop demo cannot replace its own executable: download a verified installer from official GitHub Releases.':'A newer web version is ready. Installing the web update reloads this page; local saves stay on this device.'));root.append(button(localDesktopDemo()?'View downloads':'Install update',applyUpdate));root.append(button('Remind me later',()=>{save({deferVersion:latest.version,deferUntil:Date.now()+86400000});root.hidden=true}));root.append(button('View details',()=>{root.hidden=true;openSettings()}));root.hidden=false}
function tryAutoWebUpdate(){
 if(!newAvailable()||localDesktopDemo())return false;
 const prefs=saved();
 if(prefs.deferVersion===latest.version&&Date.now()<(prefs.deferUntil||0))return false;
 const active=$('itamar-player')||$('itamar-games');
 const focused=document.activeElement;
 const editing=focused&&['INPUT','TEXTAREA','SELECT'].includes(focused.tagName);
 if(active||editing||document.fullscreenElement)return false;
 try{
  if(sessionStorage.getItem('itamaros-auto-applied')===latest.version)return false;
  sessionStorage.setItem('itamaros-auto-applied',latest.version);
 }catch{return false}
 const url=new URL(location.href);
 url.searchParams.set('itamaros-update',Date.now().toString());
 location.replace(url.href);
 return true;
}
function applyUpdate(){if(!newAvailable())return;if(localDesktopDemo()){window.open('https://github.com/itamarnintendo04-arch/ItamarOS/releases','_blank','noopener');return}const msg='Update now? The page will reload. Unsaved edits and media playback may stop. Saved games and notes remain in this browser.';if(!confirm(msg))return;save({deferVersion:null,deferUntil:0});const u=new URL(location.href);u.searchParams.set('itamaros-update',Date.now().toString());location.replace(u.href)}
async function check(manual=false){
 if(checking)return checking;
 checking=(async()=>{
   try{
    const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),12000);
    let response;try{response=await fetch(MANIFEST+'?t='+Date.now(),{cache:'no-store',signal:controller.signal})}finally{clearTimeout(timeout)}
    if(!response.ok)throw Error('GitHub returned HTTP '+response.status);
    const m=await response.json();if(!validManifest(m))throw Error('Invalid update manifest');
    latest=m;lastError='';lastCheck=Date.now();
    save({lastChecked:lastCheck});render();
    if(newAvailable()){if(!manual&&tryAutoWebUpdate())return m;showToast(manual)}
    else if(manual)displayMessage('You have the latest web version ('+BUILD+').');
    return m;
   }catch(e){lastCheck=Date.now();lastError=e.message||'Unknown error';render();if(manual)displayMessage('Update check failed: '+lastError);return null}
   finally{checking=null}
 })();return checking;
}
function displayMessage(t){const status=id('ios-updates-message');if(status)status.textContent=t}
function rowComponent(container,c){
 const box=el('div',undefined,'ios-pane');
 box.append(el('strong',c.name||c.id));
 const text=el('p','Installed web bundle: '+BUILD+' · Published: '+c.version,'ios-caption');
 box.append(text);
 if(compare(c.version,BUILD)>0&&c.delivery==='bundled')box.append(button('Update app',applyUpdate));
 else if(compare(c.version,BUILD)>0&&c.delivery==='reload')box.append(button('Update system',applyUpdate));
 else box.append(el('p','Built in · Up to date','ios-success'));
 container.append(box)
}
function render(){
 const root=id('ios-updates-content');if(!root)return;
 root.replaceChildren();
 const status=el('div',undefined,'ios-notice');
 status.append(el('strong','Installed browser edition: '+BUILD));
 status.append(el('p',lastError?'Last check failed: '+lastError:newAvailable()?'Web update '+latest.version+' is available.':'All installed web components are current (as last checked).'));
 status.append(el('small',lastCheck?'Checked: '+new Date(lastCheck).toLocaleString():'Not checked yet'));
 root.append(status);
 const tools=el('div',undefined,'ios-row');
 tools.append(button('Check for updates',()=>check(true)));
 if(newAvailable()){tools.append(button(localDesktopDemo()?'View downloads':'Update now',applyUpdate));tools.append(button('Remind me later',()=>{save({deferVersion:latest.version,deferUntil:Date.now()+86400000});const toast=id('ios-update-toast');if(toast)toast.hidden=true;displayMessage('Reminder postponed for 24 hours.')}))}
 root.append(tools);
 root.append(el('p',localDesktopDemo()?'Desktop demo packages must be updated using a verified published desktop release. This program cannot replace its own binary.':'When a new web version is published to GitHub and deployed on Render, it can be installed by reloading this page. Native OS packages require a separate signed system updater.','ios-caption'));
 const msg=el('p','','ios-caption');msg.id='ios-updates-message';root.append(msg);
 const headings=el('h3','Installed applications');root.append(headings);
 if(latest){for(const c of latest.components)rowComponent(root,c);
   if(Array.isArray(latest.notes)){const details=el('details');details.append(el('summary','What is new'));const list=el('ul');for(const note of latest.notes.slice(0,MAX_NOTES))list.append(el('li',note));details.append(list);root.append(details)}}
 else root.append(el('p','Use Check for updates to load the list of installed web components.','ios-caption'));
 root.append(el('h3','Install ItamarOS on this device'));
 const pwa=el('p','If your browser supports installing this website as an app, the Install button can be used. This does not replace your phone, TV or computer operating system.','ios-caption');root.append(pwa);
 if(installedPrompt)root.append(button('Install web app',async()=>{const p=installedPrompt;installedPrompt=null;try{await p.prompt();await p.userChoice}catch{}render()}));
 else root.append(el('p','For supported browsers, use the browser menu → Add to Home Screen / Install app.','ios-caption'));
 const native=el('p',undefined,'ios-caption');native.append('Native OS installation packages are not published yet. ');
 const link=el('a','Official downloads');link.className='ios-link';link.href='/downloads.html';link.target='_blank';link.rel='noopener noreferrer';native.append(link);root.append(native);
}
function openSettings(){
 const c=id('content'),win=id('window');if(!c||!win)return;
 win.classList.remove('hidden');id('title').textContent='Settings · Software Updates';
 c.replaceChildren();
 const box=el('section',undefined,'ios-feature');
 box.append(el('h2','Software Updates'));box.append(el('p','Update the ItamarOS web edition and its built-in applications.','ios-caption'));
 const child=el('div');child.id='ios-updates-content';box.append(child);c.append(box);
 render();if(!lastCheck)check(false);
}
function init(){
 window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installedPrompt=event;render()});
 window.addEventListener('appinstalled',()=>{installedPrompt=null;render()});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden&&Date.now()-lastCheck>15*60*1000)check(false)});
 window.addEventListener('focus',()=>{if(Date.now()-lastCheck>30*60*1000)check(false)});
 setInterval(()=>{if(!document.hidden)check(false)},30*60*1000);
 setTimeout(()=>check(false),1100);
}
window.ItamarUpdates={BUILD,check,openSettings,applyUpdate};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();