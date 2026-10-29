/* ItamarOS TV Streaming 1.1: TV-only regional catalog and native application launch requests.
 * Runs in a TV browser or a future signed/native TV shell.
 * The normal browser has no right to start installed apps and we never pretend it does. */
(()=>{'use strict';
const $=id=>document.getElementById(id);
const el=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e};
const maybeButton=(name,handler)=>{const b=el('button',name);b.type='button';b.onclick=handler;return b};
const PROVIDERS=Object.freeze([
 {id:'netflix',name:'Netflix',symbol:'N',scope:'global',apps:{android:'com.netflix.ninja',tizen:'3201907018807',webos:'netflix'}},
 {id:'disney',name:'Disney+',symbol:'D+',scope:'global',apps:{android:'com.disney.disneyplus',tizen:'3201901017640',webos:'com.disney.disneyplus-prod'}},
 {id:'appletv',name:'Apple TV',symbol:'TV',scope:'global',apps:{}},
 {id:'youtube',name:'YouTube',symbol:'▶',scope:'global',apps:{android:'com.google.android.youtube.tv',tizen:'111299001912',webos:'youtube.leanback.v4'}},
 {id:'prime',name:'Prime Video',symbol:'P',scope:'global',apps:{android:'com.amazon.amazonvideo.livingroom',tizen:'3201910019365',webos:'amazon'}},
 {id:'kan',name:'כאן BOX',symbol:'כאן',countries:['IL'],apps:{}},
 {id:'yes',name:'yes+',symbol:'yes',countries:['IL'],apps:{}},
 {id:'hot',name:'HOT',symbol:'HOT',countries:['IL'],apps:{}},
 {id:'hulu',name:'Hulu',symbol:'H',countries:['US'],apps:{tizen:'3201601007625'}},
 {id:'peacock',name:'Peacock',symbol:'P+',countries:['US'],apps:{}}
]);
const KNOWN_TZ=Object.freeze({
 'Asia/Jerusalem':'IL','Asia/Tel_Aviv':'IL',
 'Europe/London':'GB','Europe/Dublin':'IE','Europe/Paris':'FR','Europe/Berlin':'DE','Europe/Madrid':'ES','Europe/Rome':'IT',
 'America/Los_Angeles':'US','America/Chicago':'US','America/Denver':'US','America/Detroit':'US','America/Phoenix':'US',
 'America/Toronto':'CA','America/Vancouver':'CA','America/Edmonton':'CA','America/Halifax':'CA',
 'Australia/Sydney':'AU','Australia/Melbourne':'AU','Australia/Perth':'AU','Australia/Brisbane':'AU',
 'Pacific/Auckland':'NZ','Asia/Tokyo':'JP','Asia/Seoul':'KR'
});
function regionFromLocale(){
 for(const lang of navigator.languages||[navigator.language]){try{
   const country=new Intl.Locale(lang).region;
   if(country&&/^[A-Z]{2}$/.test(country))return country
 }catch{}}
 return null
}
function detectRegion(){
 let timezone='';try{timezone=Intl.DateTimeFormat().resolvedOptions().timeZone||''}catch{}
 if(KNOWN_TZ[timezone])return {country:KNOWN_TZ[timezone],source:'time zone'};
 const locale=regionFromLocale();
 if(locale)return {country:locale,source:'browser language'};
 return {country:null,source:'unknown'};
}
function devicePlatform(){
 const ua=navigator.userAgent||'';
 if(window.tizen?.application?.launch)return 'tizen';
 if(window.webOS?.service?.request)return 'webos';
 if(window.ItamarOSTVNative?.launchApp)return 'android-native';
 if(/Tizen/i.test(ua))return 'tizen-browser';
 if(/Web0S|WebOS/i.test(ua))return 'webos-browser';
 if(/Android TV|GoogleTV|AFT[A-Z0-9]+/i.test(ua))return 'android-browser';
 return 'browser';
}
function serviceList(country){
 return PROVIDERS.filter(p=>p.scope==='global'||(country&&p.countries?.includes(country)));
}
function status(message){const n=$('tv-stream-status');if(n)n.textContent=message}
function launchedMessage(name){status('Launch requested for '+name+'. If the application is not installed or blocked by the TV, open it from the television Home screen.')}
function unsupported(name){
 status('This TV browser cannot directly start '+name+'. Use your TV Home screen or App Store to open the official app. A compatible installed TV application/bridge is required for direct launch.');
}
function launchProvider(id){
 if(document.body?.dataset?.device!=='tv'){status('Streaming is available in TV mode only.');return false}
 const provider=PROVIDERS.find(p=>p.id===id);if(!provider){status('Unknown service.');return false}
 const platform=devicePlatform();
 try{
  if(platform==='tizen'&&provider.apps.tizen){
   window.tizen.application.launch(provider.apps.tizen,()=>launchedMessage(provider.name),err=>status('TV could not launch '+provider.name+': '+String(err?.message||'not installed or unsupported')+'. Use TV Home.'));return true;
  }
  if(platform==='webos'&&provider.apps.webos){
   window.webOS.service.request('luna://com.webos.applicationManager',{
     method:'launch',parameters:{id:provider.apps.webos},
     onSuccess:response=>response?.returnValue===false?status('TV refused to launch '+provider.name+'. Check installation and permissions.'):launchedMessage(provider.name),
     onFailure:error=>status('TV could not launch '+provider.name+': '+String(error?.errorText||'not installed or unavailable')+'. Use TV Home.')
   });return true;
  }
  if(platform==='android-native'&&provider.apps.android){
   // Only an approved host bridge can query installed apps; normal websites cannot.
   const res=window.ItamarOSTVNative.launchApp(provider.apps.android);
   if(res===false){status('App not installed or blocked. Open it from the TV Home screen.');return false}
   launchedMessage(provider.name);return true;
  }
 }catch{status('TV application launch failed. Open '+provider.name+' using the TV Home screen.');return false}
 unsupported(provider.name);return false;
}
function mount(){
 const target=$('content');if(!target||document.body?.dataset?.device!=='tv')return false;
 target.replaceChildren();
 const root=el('section',undefined,'tv-stream');
 root.append(el('h2','📺 TV Streaming'));
 const found=detectRegion();
 const line=el('p','Country: '+(found.country||'Unknown')+' · estimated from '+found.source+'. No GPS or precise location is requested.','tv-region');
 root.append(line);
 root.append(el('p','Choose a service to launch its installed TV app when this TV platform allows it. Availability, subscriptions, and app IDs differ by TV model and country.','tv-help'));
 const row=el('div',undefined,'tv-region-controls');
 const label=el('label','Country / region: ');
 const select=el('select');select.id='tv-country';
 const options=[['auto','Automatic ('+(found.country||'unknown')+')'],['IL','Israel'],['US','United States'],['GB','United Kingdom'],['CA','Canada'],['AU','Australia'],['other','Other']];
 for(const [v,n] of options){const option=el('option',n);option.value=v;select.append(option)}
 label.append(select);row.append(label);
 const platform=el('span','TV platform: '+devicePlatform().replace('-',' '),'tv-platform');row.append(platform);root.append(row);
 const services=el('div',undefined,'tv-stream-list');services.id='tv-stream-list';root.append(services);
 const message=el('p','', 'tv-stream-status');message.id='tv-stream-status';message.setAttribute('role','status');root.append(message);
 root.append(el('p','Direct opening works only inside a properly installed Samsung Tizen, LG webOS or supported Android TV host. A regular TV web browser cannot control installed apps.','tv-help'));
 target.append(root);
 function updateList(){
  const country=select.value==='auto'?found.country:(select.value==='other'?null:select.value);
  line.textContent='Country: '+(country||'Unknown')+(select.value==='auto'?' · estimated from '+found.source:' · manually selected')+'. No GPS or precise location is used.';
  services.replaceChildren();
  for(const provider of serviceList(country)){
   const button=maybeButton('',()=>launchProvider(provider.id));button.className='tv-provider';
   const logo=el('span',provider.symbol,'tv-provider-mark');button.append(logo,el('span',provider.name));
   button.setAttribute('aria-label','Open '+provider.name+' application on TV');
   services.append(button)
  }
  status('Select a service. TV launcher permissions and installed apps determine whether opening succeeds.');
 }
 select.onchange=updateList;updateList();return true
}
window.ItamarTVStreaming=Object.freeze({mount,launchProvider,detectRegion,devicePlatform,serviceList});
})();
