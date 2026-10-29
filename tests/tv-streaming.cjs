'use strict';
/* Tests for auto-region TV streaming and supported native platform APIs.
 * Native TV-specific app installation must still be tested on actual TV hardware. */
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../apps/tv-streaming.js'),'utf8');
new vm.Script(source);
function instantiate({tz='Asia/Jerusalem',langs=['he-IL'],mode='tv',platform='tizen'}={}){
 const calls=[];const status={textContent:''};
 const fakeDocument={
  body:{dataset:{device:mode}},
  getElementById:id=>id==='tv-stream-status'?status:null
 };
 const window={};
 if(platform==='tizen')window.tizen={application:{launch(id,success,error){calls.push(id);success()}}};
 if(platform==='webos')window.webOS={service:{request(uri,arg){calls.push({uri,id:arg.parameters.id});arg.onSuccess({returnValue:true})}}};
 if(platform==='android-native')window.ItamarOSTVNative={launchApp(pkg){calls.push(pkg);return true}};
 const customIntl={...Intl,Locale:Intl.Locale,DateTimeFormat:()=>({resolvedOptions:()=>({timeZone:tz})})};
 const ctx={window,document:fakeDocument,navigator:{userAgent:platform==='tizen'?'Tizen SmartTV':platform==='webos'?'Web0S TV':'Android TV',languages:langs,language:langs[0]},Intl:customIntl,console};
 vm.runInNewContext(source,ctx);
 return{streaming:window.ItamarTVStreaming,calls,status,ctx};
}
const israel=instantiate();
assert.equal(israel.streaming.detectRegion().country,'IL');
assert.equal(israel.streaming.detectRegion().source,'time zone');
const names=israel.streaming.serviceList('IL').map(x=>x.name);
for(const name of ['Netflix','Disney+','Apple TV','YouTube','Prime Video','כאן BOX','yes+','HOT'])assert.ok(names.includes(name),name);
assert.ok(!names.includes('Hulu'));
assert.equal(israel.streaming.launchProvider('netflix'),true);
assert.equal(israel.calls[0],'3201907018807');
assert.match(israel.status.textContent,/Launch requested/);

const us=instantiate({tz:'America/Los_Angeles',langs:['en-US'],platform:'webos'});
assert.equal(us.streaming.detectRegion().country,'US');
assert.ok(us.streaming.serviceList('US').some(x=>x.name==='Hulu'));
assert.ok(!us.streaming.serviceList('US').some(x=>x.name==='yes+'));
assert.equal(us.streaming.launchProvider('disney'),true);
assert.equal(us.calls[0].id,'com.disney.disneyplus-prod');

const locale=instantiate({tz:'Etc/UTC',langs:['he-IL'],platform:'android-native'});
assert.equal(locale.streaming.detectRegion().country,'IL','Fallback to browser locale only if timezone unknown');
assert.equal(locale.streaming.launchProvider('youtube'),true);
assert.equal(locale.calls[0],'com.google.android.youtube.tv');

const ordinary=instantiate({tz:'Asia/Jerusalem',platform:'browser'});
assert.equal(ordinary.streaming.launchProvider('netflix'),false);
assert.equal(ordinary.calls.length,0);
assert.match(ordinary.status.textContent,/cannot directly start/);

const nonTV=instantiate({mode:'desktop',platform:'tizen'});
assert.equal(nonTV.streaming.launchProvider('netflix'),false);
assert.equal(nonTV.calls.length,0);
assert.ok(nonTV.streaming.serviceList('GB').some(x=>x.name==='Netflix'));

console.log('TV Streaming: country detection, regional services, TV gate, Tizen, webOS and Android bridge tests passed.');
