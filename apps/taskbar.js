/* ItamarOS taskbar. Pinned apps persist; open windows remain in this session until closed.
   Window DOM is parked between app switches, preserving handlers and user-entered state. */
(()=>{'use strict';
const KEY='itamaros-taskbar-v1';
const DEFAULT=['files','browser','player','games','settings'];
const LABELS={welcome:'Start',notes:'Notepad',files:'Files',terminal:'Terminal',calculator:'Calculator',browser:'Browser',settings:'Settings',store:'Store',player:'ItamarOS Player',games:'ItamarOS Games',youtubewebview:'YouTube WebView',github:'GitHub',streaming:'TV Streaming',weather:'Weather',contacts:'Contacts',journal:'Journal',converter:'Converter',passwords:'Password Tools',timer:'Timer',stopwatch:'Stopwatch',whiteboard:'Whiteboard',bookmarks:'Bookmarks',downloads:'Downloads',about:'About',shortcuts:'Shortcuts',reader:'Reader',random:'Random',colors:'Colors',json:'JSON Viewer'};
const ICONS={welcome:'itamaros',notes:'notes',json:'json',streaming:'streaming',youtubewebview:'youtubewebview'};
const TV_SUPPORTED=new Set(['welcome','player','games','streaming','settings','browser','youtubewebview','weather','clock','about']);
const supported=id=>Object.hasOwn(LABELS,id)&&(document.body.dataset.device==='tv'?TV_SUPPORTED.has(id):id!=='streaming');
const $=id=>document.getElementById(id);
function readPins(){try{const v=JSON.parse(localStorage.getItem(KEY));if(Array.isArray(v))return [...new Set(v.filter(id=>typeof id==='string'&&supported(id)))].slice(0,30)}catch{}return DEFAULT.filter(supported)}
let pinned=readPins();const running=new Map();
let active=null;
let popup=null;
const originalLaunch=window.launch,originalClose=window.closeWindow,originalMinimize=window.minimizeWindow;
function savePins(){try{localStorage.setItem(KEY,JSON.stringify(pinned))}catch{}}
function button(text,action){const b=document.createElement('button');b.type='button';b.textContent=text;b.onclick=action;return b}
function iconFor(id){return id==='welcome'?'/assets/branding/itamaros-mark-512.png':'/assets/icons/'+(ICONS[id]||id)+'.svg'}
function cleanPopup(){if(popup){popup.remove();popup=null}}
function positionPopup(id,x,y){
 cleanPopup();const n=document.createElement('div');n.className='it-taskbar-menu';n.setAttribute('role','menu');
 const p=pinned.includes(id);n.append(button(p?'Unpin from taskbar':'Pin to taskbar',()=>{togglePin(id);cleanPopup()}));
 if(running.has(id))n.append(button('Close window',()=>{closeApp(id);cleanPopup()}));
 document.body.append(n);const maxX=window.innerWidth-210,maxY=window.innerHeight-100;
 n.style.left=Math.max(8,Math.min(x,maxX))+'px';n.style.top=Math.max(8,Math.min(y,maxY))+'px';popup=n
}
function trackCurrent(){
 if(!active||!running.has(active))return;
 const w=$('window'),content=$('content');if(!w||!content)return;
 const entry=running.get(active);
 entry.title=$('title')?.textContent||LABELS[active]||active;
 entry.nodes=[...content.childNodes];
 content.replaceChildren();
}
function restore(id){
 const entry=running.get(id);if(!entry)return false;
 const content=$('content'),w=$('window');if(!content||!w)return false;
 content.replaceChildren(...(entry.nodes||[]));entry.nodes=[];if($('title'))$('title').textContent=entry.title||LABELS[id]||id;
 w.classList.remove('hidden');active=id;render();return true
}
function open(id){
 if(!supported(id))return false;
 if(active===id){
   $('window')?.classList.remove('hidden');render();return true;
 }
 trackCurrent();
 active=null;
 if(restore(id))return true;
 if(typeof originalLaunch!=='function')return false;
 originalLaunch(id);
 running.set(id,{title:$('title')?.textContent||LABELS[id]||id,nodes:[]});
 active=id;
 if(id==='settings'&&window.ItamarSettings?.mount)window.ItamarSettings.mount();
 render();return true
}
function closeApp(id=active){
 if(!id||!running.has(id))return;
 if(id==='player')window.ItamarPlayer?.release?.();
 if(id==='games')window.ItamarGames?.cleanup?.();
 if(active===id){
   $('content')?.replaceChildren();$('window')?.classList.add('hidden');active=null;
 }else{const entry=running.get(id);for(const node of entry.nodes||[]){if(node.remove)node.remove()}}
 running.delete(id);render()
}
function minimize(){if(typeof originalMinimize==='function')originalMinimize();else $('window')?.classList.add('hidden');render()}
function togglePin(id){
 if(!supported(id))return;
 if(pinned.includes(id))pinned=pinned.filter(n=>n!==id);else pinned.push(id);
 savePins();render();window.dispatchEvent(new CustomEvent('itamaros:pins-changed',{detail:{pins:[...pinned]}}))
}
function resetPins(){pinned=DEFAULT.filter(supported);savePins();render()}
function render(){
 const bar=$('taskbar-apps');if(!bar)return;bar.replaceChildren();
 const ids=[...new Set([...pinned,...running.keys()])].filter(supported);
 for(const id of ids){
   const item=document.createElement('button');item.type='button';
   const runningNow=running.has(id),visible=runningNow&&id===active&&!$('window')?.classList.contains('hidden');
   item.className='it-taskbar-app'+(runningNow?' running':'')+(visible?' selected':'');
   item.title=(LABELS[id]||id)+(runningNow?' — Running':' — Pinned');
   item.setAttribute('aria-label',(LABELS[id]||id)+(runningNow?' running':' pinned'));
   const img=document.createElement('img');img.src=iconFor(id);img.alt='';img.width=25;img.height=25;img.loading='lazy';item.append(img);
   const label=document.createElement('span');label.textContent=LABELS[id]||id;item.append(label);
   item.onclick=()=>{cleanPopup();if(id===active&&runningNow&&!$('window')?.classList.contains('hidden'))minimize();else open(id)};
   item.oncontextmenu=e=>{e.preventDefault();positionPopup(id,e.clientX,e.clientY)};
   bar.append(item)
 }
}
document.addEventListener('contextmenu',e=>{
 const app=e.target.closest?.('main.desktop .app[data-builtin="true"]');
 if(!app)return;const match=(app.getAttribute('onclick')||'').match(/launch\('([^']+)'\)/);
 if(!match||!supported(match[1]))return;
 e.preventDefault();positionPopup(match[1],e.clientX,e.clientY)
});
document.addEventListener('click',e=>{if(popup&&!popup.contains(e.target))cleanPopup()});
document.addEventListener('keydown',e=>{if(e.key==='Escape')cleanPopup()});
window.launch=id=>open(id);
window.closeWindow=()=>closeApp();
window.minimizeWindow=minimize;
window.ItamarTaskbar={open,close:closeApp,minimize,togglePin,resetPins,render,getPinned:()=>[...pinned],getRunning:()=>[...running.keys()],getActive:()=>active,labels:LABELS};
const init=()=>{if(!$('taskbar-apps'))return;if(!$('window')?.classList.contains('hidden')){
 const id='welcome';running.set(id,{title:$('title')?.textContent||'Start',nodes:[]});active=id;
 }render();};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
