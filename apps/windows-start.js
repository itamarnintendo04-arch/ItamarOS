/* The Windows Start Menu integration is available only to the packaged Electron
 * desktop app. Never scan installed apps from a browser or send inventory online. */
(()=>{'use strict';
const host=window.ItamarRuntime;
const menu=document.getElementById('appmenu');
const panel=document.getElementById('windowsPrograms');
const list=document.getElementById('windowsProgramsList');
const status=document.getElementById('windowsProgramsStatus');
const search=document.getElementById('appsearch');
if(!menu||!panel||!list||!status||!search)return;
if(host?.platform!=='win32'||typeof host.listWindowsApps!=='function'){
 panel.hidden=true;return;
}
panel.hidden=false;
let apps=[],loaded=false,busy=false;
function render(){
 list.replaceChildren();
 const query=search.value.trim().toLocaleLowerCase();
 const matched=apps.filter(app=>app.name.toLocaleLowerCase().includes(query));
 const frag=document.createDocumentFragment();
 let last='';
 for(const app of matched){
  const letter=/[a-z]/i.test(app.name[0])?app.name[0].toUpperCase():'#';
  if(letter!==last){
   const heading=document.createElement('h4');heading.className='windows-app-letter';
   heading.textContent=letter;frag.append(heading);last=letter;
  }
  const button=document.createElement('button');
  button.type='button';
  button.className='windows-installed-app';
  button.textContent=app.name;
  button.title='Open installed Windows app: '+app.name;
  button.onclick=async ()=>{
   button.disabled=true;
   status.textContent='Opening '+app.name+' in Windows…';
   try{
    const ok=await host.openWindowsApp(app.id);
    status.textContent=ok?'Opened '+app.name+' in Windows':'Could not open '+app.name+'. It may have been uninstalled.';
   }catch{
    status.textContent='Windows could not start the selected program.';
   }finally{button.disabled=false}
  };
  frag.append(button);
 }
 list.append(frag);
 if(loaded)status.textContent=matched.length+' Windows Start Menu shortcuts found'+(query?' for this search':'')+'. Some Microsoft Store apps may not appear.';
}
async function load(){
 if(busy)return;
 busy=true;status.textContent='Checking locally installed Windows apps…';
 try{
  const found=await host.listWindowsApps();
  apps=Array.isArray(found)?found.filter(x=>x&&typeof x.id==='string'&&typeof x.name==='string'&&x.name.length<180):[];
  loaded=true;render();
 }catch{status.textContent='Windows app list is unavailable.'}
 finally{busy=false}
}
search.addEventListener('input',render);
const original=window.toggleApps;
if(typeof original==='function'){
 window.toggleApps=function(...args){
  const out=original(...args);
  if(!menu.hidden&&!loaded)load();
  return out;
 };
}
})();
