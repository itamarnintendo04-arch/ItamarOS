/* ItamarOS Web Demo Settings.
   These controls change the emulator only; native PC settings are handled by KDE. */
(()=>{'use strict';
const KEY='itamaros-preferences-v1';
const DEFAULT={theme:'dark',accent:'#4b97e7',textSize:100,uiScale:100,contrast:false,reducedMotion:false,clock24:false,notifications:false,wallpaper:'blue',language:'en'};
const CATEGORIES=[
 {id:'system',icon:'💻',name:'System & Device'},
 {id:'personalization',icon:'🎨',name:'Personalization'},
 {id:'display',icon:'🖥️',name:'Display'},
 {id:'sound',icon:'🔊',name:'Sound'},
 {id:'network',icon:'🌐',name:'Network & Internet'},
 {id:'bluetooth',icon:'ᛒ',name:'Bluetooth & Devices'},
 {id:'storage',icon:'💾',name:'Storage & Files'},
 {id:'apps',icon:'📦',name:'Apps & Taskbar'},
 {id:'accounts',icon:'👤',name:'Accounts'},
 {id:'privacy',icon:'🔐',name:'Privacy & Security'},
 {id:'accessibility',icon:'♿',name:'Accessibility'},
 {id:'time',icon:'🕒',name:'Time & Language'},
 {id:'power',icon:'🔋',name:'Power & Battery'},
 {id:'updates',icon:'🔄',name:'Software Updates'},
 {id:'backup',icon:'📁',name:'Backup & Restore'},
 {id:'about',icon:'ℹ️',name:'About'}
];
const $=id=>document.getElementById(id);
function load(){try{const value=JSON.parse(localStorage.getItem(KEY));if(!value||typeof value!=='object')return {...DEFAULT};return {...DEFAULT,...value}}catch{return {...DEFAULT}}}
let prefs=load(),current='system';
function save(){try{localStorage.setItem(KEY,JSON.stringify(prefs))}catch{}}
function apply(){
 document.body.dataset.theme=prefs.theme;
 document.body.dataset.contrast=prefs.contrast?'high':'standard';
 document.body.dataset.wallpaper=prefs.wallpaper;
 document.documentElement.style.setProperty('--it-accent',/^#[0-9a-fA-F]{6}$/.test(prefs.accent)?prefs.accent:DEFAULT.accent);
 document.documentElement.style.setProperty('--it-scale',(Math.max(80,Math.min(130,Number(prefs.uiScale)||100))/100).toString());
 document.documentElement.style.setProperty('--it-text-scale',(Math.max(85,Math.min(150,Number(prefs.textSize)||100))/100).toString());
 document.body.classList.toggle('it-reduced-motion',!!prefs.reducedMotion);
 window.dispatchEvent(new CustomEvent('itamaros:preferences',{detail:{...prefs}}))
}
const node=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e};
function createButton(label,onClick){const b=node('button',label);b.type='button';b.addEventListener('click',onClick);return b}
function info(text){return node('p',text,'it-settings-hint')}
function row(label,value){const r=node('div',undefined,'it-settings-row');r.append(node('strong',label),node('span',value));return r}
function wrap(title,text){const el=node('section',undefined,'it-settings-panel');el.append(node('h3',title));if(text)el.append(info(text));return el}
function checkbox(label,key){
 const box=node('label',undefined,'it-settings-toggle');
 const input=node('input');input.type='checkbox';input.checked=Boolean(prefs[key]);input.addEventListener('change',()=>{prefs[key]=input.checked;save();apply()});
 box.append(input,node('span',label));return box
}
function range(label,key,min,max,unit='%'){
 const r=node('label',undefined,'it-settings-slider');
 const title=node('span',label),span=node('output',String(prefs[key])+unit);
 const inp=node('input');inp.type='range';inp.min=min;inp.max=max;inp.step=5;inp.value=prefs[key];inp.addEventListener('input',()=>{prefs[key]=Number(inp.value);span.textContent=inp.value+unit;save();apply()});
 r.append(title,inp,span);return r
}
function selector(label,key,options){
 const r=node('label',undefined,'it-settings-select');r.append(node('span',label));
 const select=node('select');for(const [value,name] of options){const o=node('option',name);o.value=value;select.append(o)}
 select.value=prefs[key];select.addEventListener('change',()=>{prefs[key]=select.value;save();apply();if(key==='clock24'||key==='language')window.refreshClock?.()});r.append(select);return r
}
function buttonRow(...buttons){const r=node('div',undefined,'it-settings-actions');r.append(...buttons);return r}
function renderCategory(){
 const area=$('it-settings-body');if(!area)return;area.replaceChildren();
 switch(current){
 case 'system':{
  const p=wrap('System & Device','Hardware shown by a browser is limited. ItamarOS Linux uses native system services for full hardware detection.');
  p.append(row('Edition','ItamarOS Web Demo 1.1'),row('Device layout',document.body.dataset.device||'unknown'),row('Platform',navigator.userAgentData?.platform||navigator.platform||'Browser'),row('CPU cores reported',String(navigator.hardwareConcurrency||'Not exposed')),row('Approx. RAM',navigator.deviceMemory?navigator.deviceMemory+' GiB':'Not exposed'),row('Online',navigator.onLine?'Connected':'Offline'));
  p.append(buttonRow(createButton('Check updates',()=>window.ItamarUpdates?.openSettings()),createButton('Open full PC settings',()=>showCategory('about'))));
  area.append(p);break
 }
 case 'personalization':{
  const p=wrap('Personalization','Customize the ItamarOS demo. These options are remembered on this browser.');
  p.append(selector('Theme','theme',[['dark','Dark'],['light','Light']]));
  p.append(selector('Wallpaper','wallpaper',[['blue','Aurora blue'],['purple','Nebula purple'],['green','Ocean green'],['midnight','Midnight']]));
  const accent=node('label','Accent color ');const color=node('input');color.type='color';color.value=prefs.accent;color.addEventListener('input',()=>{prefs.accent=color.value;save();apply()});accent.append(color);p.append(accent);
  p.append(buttonRow(createButton('Reset appearance',()=>{prefs.theme=DEFAULT.theme;prefs.wallpaper=DEFAULT.wallpaper;prefs.accent=DEFAULT.accent;save();apply();renderCategory()})));
  area.append(p);break
 }
 case 'display':{
  const p=wrap('Display & Scaling','Browser apps cannot change physical resolution, monitor refresh rate or hardware brightness.');
  p.append(range('Interface scale','uiScale',80,130),range('Text size','textSize',85,150),checkbox('High contrast','contrast'));
  p.append(info('To change the display resolution and orientation, use your device System Settings.'));
  area.append(p);break
 }
 case 'sound':{
  const p=wrap('Sound','Browser audio controls cannot change your operating system master volume or audio device drivers.');
  p.append(info('The ItamarOS Player has its own volume, 10-band equalizer, and playback speed controls.'));
  p.append(buttonRow(createButton('Open Player',()=>window.launch?.('player')),createButton('Test sound',()=>{try{const audio=new (window.AudioContext||window.webkitAudioContext)();const osc=audio.createOscillator(),gain=audio.createGain();gain.gain.value=.06;osc.frequency.value=550;osc.connect(gain).connect(audio.destination);osc.start();osc.stop(audio.currentTime+.16);osc.onended=()=>audio.close()}catch{alert('Audio test is not available in this browser.')}})));
  area.append(p);break
 }
 case 'network':{
  const p=wrap('Network & Internet','Wi-Fi, Ethernet and VPN connections must be configured in your device operating system.');
  p.append(row('Status',navigator.onLine?'Online':'Offline'));
  p.append(row('Connection',navigator.connection?.effectiveType||'Not exposed by browser'));
  p.append(buttonRow(createButton('Refresh connection status',renderCategory)));
  area.append(p);break
 }
 case 'bluetooth':{
  const p=wrap('Bluetooth & Devices','This demo does not request Bluetooth device access or pairing permissions.');
  p.append(row('Device category',document.body.dataset.device||'unknown'));
  p.append(info('Bluetooth pairing, USB devices, keyboards, touchpads, gamepads, printers, microphones and cameras are configured through your host system. The native ItamarOS Linux edition provides KDE device settings.'));
  area.append(p);break
 }
 case 'storage':{
  const p=wrap('Storage & Files','Saved demo files, games and preferences live in your browser profile, not a cloud drive.');
  const result=node('p','Checking browser storage…','it-settings-hint');p.append(result);
  const show=async()=>{if(!navigator.storage?.estimate){result.textContent='Storage estimate unavailable in this browser.';return}try{const e=await navigator.storage.estimate();const fmt=n=>n===undefined?'Unknown':(n/1048576).toFixed(1)+' MiB';result.textContent='Estimated usage: '+fmt(e.usage)+' / browser quota '+fmt(e.quota)+' (not your total disk capacity).'}catch{result.textContent='Storage estimate unavailable.'}};
  p.append(buttonRow(createButton('Refresh usage',show),createButton('Open Files',()=>window.launch?.('files'))));area.append(p);show();break
 }
 case 'apps':{
  const p=wrap('Apps & Taskbar','Pinned apps remain on your taskbar. Open apps appear there until closed.');
  const list=node('div',undefined,'it-settings-apps');
  const ids=Object.keys(window.ItamarTaskbar?.labels||{}).filter(id=>id!=='welcome'&&(id!=='streaming'||document.body.dataset.device==='tv'));
  for(const id of ids){
   const item=node('label',undefined,'it-settings-app');
   const box=node('input');box.type='checkbox';box.checked=window.ItamarTaskbar?.getPinned?.().includes(id)||false;
   box.addEventListener('change',()=>window.ItamarTaskbar?.togglePin?.(id));
   const icon=node('img');icon.alt='';icon.src='/assets/icons/'+(id==='notes'?'notes':id)+'.svg';icon.width=24;icon.height=24;
   item.append(box,icon,node('span',window.ItamarTaskbar?.labels?.[id]||id));list.append(item)
  }
  p.append(list);p.append(buttonRow(createButton('Restore default pins',()=>{window.ItamarTaskbar?.resetPins?.();renderCategory()})));
  p.append(row('Running apps',(window.ItamarTaskbar?.getRunning?.()||[]).map(id=>window.ItamarTaskbar.labels[id]||id).join(', ')||'None'));
  area.append(p);break
 }
 case 'accounts':{
  const p=wrap('Accounts','This is an offline-capable web demo. No account is required or created.');
  p.append(row('Account','Local browser profile'));
  p.append(info('The demo does not link your operating-system account, Apple ID, Google account or Google Drive. Never type system credentials into a demo profile.'));
  area.append(p);break
 }
 case 'privacy':{
  const p=wrap('Privacy & Security','Browser permission controls and system antivirus settings are managed outside this demo.');
  p.append(row('Website origin',location.origin));
  p.append(row('Notifications permission',('Notification' in window)?Notification.permission:'Unavailable'));
  p.append(buttonRow(createButton('Review notification permission',async()=>{if(!('Notification' in window)){alert('Notifications are not supported.');return}try{const res=await Notification.requestPermission();alert('Notifications: '+res)}catch{alert('Notifications permission unavailable.')}})));
  p.append(info('The demo cannot scan your PC, read Avast warnings, or disable operating-system security protections.'));
  area.append(p);break
 }
 case 'accessibility':{
  const p=wrap('Accessibility','These settings affect ItamarOS demo windows only.');
  p.append(checkbox('Reduce animations','reducedMotion'),checkbox('High contrast','contrast'),range('Text size','textSize',85,150));
  area.append(p);break
 }
 case 'time':{
  const p=wrap('Time & Language','Your device controls the underlying clock and time zone.');
  p.append(row('Local time',new Date().toLocaleString()));
  p.append(row('Time zone',Intl.DateTimeFormat().resolvedOptions().timeZone||'Unknown'));
  p.append(checkbox('Use 24-hour clock','clock24'),selector('Preferred language','language',[['en','English'],['he','עברית'],['es','Español'],['fr','Français'],['de','Deutsch']]));
  p.append(info('This preference changes time formatting where supported. A full interface translation is not available yet.'));
  area.append(p);break
 }
 case 'power':{
  const p=wrap('Power & Battery','The web demo cannot shut down or change the power modes of your actual computer, phone or TV.');
  const output=node('p','Battery information may not be exposed by this browser.');p.append(output);
  if(navigator.getBattery)navigator.getBattery().then(b=>{if(output.isConnected)output.textContent='Battery: '+Math.round(b.level*100)+'% · '+(b.charging?'Charging':'Not charging')}).catch(()=>{});
  area.append(p);break
 }
 case 'updates':{
  const p=wrap('Software Updates','GitHub stable version checks for the web demo; native app installation is handled by native systems.');
  p.append(buttonRow(createButton('Check for updates',()=>window.ItamarUpdates?.check?.(true)),createButton('Open update details',()=>window.ItamarUpdates?.openSettings?.())));
  area.append(p);break
 }
 case 'backup':{
  const p=wrap('Backup & Restore','Export the browser demo settings, notes and saved games as JSON. Keep this backup private.');
  p.append(buttonRow(createButton('Export my demo data',exportLocal),createButton('Reset appearance',()=>{prefs={...DEFAULT};save();apply();renderCategory()})));
  p.append(info('Import is intentionally not enabled here: arbitrary files could overwrite your current saves. Files on this device are not uploaded.'));
  area.append(p);break
 }
 case 'about':{
  const p=wrap('About ItamarOS','Version 1.1 · Native app projects for iOS, tvOS, Android and Android TV are separate from this browser demo.');
  const img=node('img');img.src='/assets/branding/itamaros-mark-512.png';img.alt='ItamarOS';img.className='it-settings-logo';p.prepend(img);
  p.append(row('Browser app','1.1.0'),row('Type','Demo / simulation'),row('OS controls','Limited to browser permissions'));
  p.append(info('The true PC operating system source is a Debian/KDE build prototype and is not a verified universal installer.'));
  area.append(p);break
 }
 }
}
function showCategory(id){if(!CATEGORIES.some(c=>c.id===id))return;current=id;
 for(const btn of document.querySelectorAll('[data-settings-tab]')){const yes=btn.dataset.settingsTab===id;btn.classList.toggle('active',yes);btn.setAttribute('aria-selected',String(yes))}
 const heading=$('it-settings-title');if(heading)heading.textContent=CATEGORIES.find(x=>x.id===id).name;
 renderCategory()
}
function mount(){
 const content=$('content');if(!content)return;content.replaceChildren();
 const root=node('section',undefined,'it-settings');
 const side=node('nav',undefined,'it-settings-sidebar');side.setAttribute('aria-label','Settings categories');
 const brand=node('h2','⚙️ Settings');side.append(brand);
 const tabs=node('div',undefined,'it-settings-tabs');
 for(const item of CATEGORIES){const b=createButton(item.icon+'  '+item.name,()=>showCategory(item.id));b.dataset.settingsTab=item.id;tabs.append(b)}side.append(tabs);
 const pane=node('section',undefined,'it-settings-main');pane.append(node('h2','System','it-settings-title'));pane.lastChild.id='it-settings-title';
 const body=node('div');body.id='it-settings-body';pane.append(body);root.append(side,pane);content.append(root);showCategory(current)
}
function exportLocal(){
 const keys=['itamaros-data','itamaros-games-v1','itamaros-game-pack-v1','itamaros-preferences-v1','itamaros-taskbar-v1','itamaros-player-prefs','itamaros-update-preferences'];
 const snapshot={format:'ItamarOS Web Demo Data Export',version:1,date:new Date().toISOString(),items:{}};
 for(const key of keys){try{const value=localStorage.getItem(key);if(value!==null)snapshot.items[key]=JSON.parse(value)}catch{}}
 const blob=new Blob([JSON.stringify(snapshot,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);
 const a=document.createElement('a');a.href=url;a.download='ItamarOS-demo-backup.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),2000)
}
window.ItamarSettings={mount,showCategory,getPreferences:()=>({...prefs}),apply};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',apply,{once:true});else apply();
})();
