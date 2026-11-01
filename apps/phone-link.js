/* ItamarPhone private pairing — only same-account, explicitly approved data.
 * QR is generated locally from a one-time secret (never an external QR API).
 * Does not access device SMS, call history, contacts or passcode fields. */
(()=>{'use strict';
const $=id=>document.getElementById(id);
const config=window.ITAMAR_CONNECT||{};
if(!/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(config.url||'')||
   !(config.publishableKey||'')||!window.supabase?.createClient){
 $('unconfigured').hidden=false;return;
}
$('unconfigured').hidden=true;
const client=window.supabase.createClient(config.url,config.publishableKey,{
 auth:{persistSession:true,autoRefreshToken:true,
       storageKey:'itamaros-connect-web-auth',detectSessionInUrl:false}
});
let user=null,currentSecret=null,preview=null;
const match=location.hash.match(/^#pair=([0-9a-f]{48})$/);
let incoming=match?match[1]:null;
// Prevent token leaking in browser history, logs or referrer.
if(location.hash)history.replaceState(null,'',location.pathname+location.search);
function error(text){$('error').textContent=String(text||'').slice(0,350)}
async function run(fn){try{await fn();error('')}catch(e){error(e?.message||'Unable to complete request')}}
async function rpc(name,body={}){
 const {data,error}=await client.rpc(name,body);
 if(error)throw error;
 return data;
}
function state(){
 $('login').hidden=!!user;
 $('pairedApp').hidden=!user;
 if(!user)return;
 $('phone').hidden=!incoming;
 $('desktop').hidden=!!incoming;
 if(incoming)run(loadInvite)();
 run(loadPairs)();
}
async function session(){
 const {data,error}=await client.auth.getUser();
 user=error?null:data?.user||null;
 state();
}
async function loadInvite(){
 if(!incoming||!user)return;
 const rows=await rpc('itamar_pair_preview',{p_code:incoming});
 const item=Array.isArray(rows)?rows[0]:null;
 if(!item){
  preview=null;$('pairInfo').textContent='This invitation is not valid, was already accepted, or belongs to another account.';
  $('approve').disabled=true;return;
 }
 preview=item;$('approve').disabled=false;
 const choices=[
  item.sync_chats?'Connect chats':'',
  item.sync_contacts?'saved Connect contacts':'',
  item.sync_files?'selected files (not yet supported)':''
 ].filter(Boolean);
 $('pairInfo').textContent='Connect to '+item.desktop_name+'? Requested sync: '+
  (choices.length?choices.join(', '):'none')+
  '. You can revoke this computer later. This does not grant SMS or phone-call access.';
}
async function loadPairs(){
 if(!user)return;
 const rows=await rpc('itamar_my_device_pairs');
 $('devices').replaceChildren();
 if(!rows?.length){$('devices').textContent='No paired or pending devices yet.';return}
 for(const pair of rows){
  const row=document.createElement('div');row.className='row';
  const label=document.createElement('span');
  label.textContent=pair.desktop_name+(pair.phone_name?' · '+pair.phone_name:'')+
   (pair.revoked_at?' · revoked':pair.claimed_at?' · paired':' · pending')+
   ' · '+[pair.sync_chats?'chats':'',pair.sync_contacts?'contacts':''].filter(Boolean).join(', ');
  row.append(label);
  if(!pair.revoked_at){
   const revoke=document.createElement('button');revoke.textContent='Revoke';revoke.type='button';
   revoke.onclick=()=>run(async()=>{
    if(!confirm('Revoke this device pairing?'))return;
    await rpc('itamar_revoke_pair',{p_pair:pair.id});await loadPairs();
   });
   row.append(revoke);
  }
  $('devices').append(row);
 }
}
$('authForm').addEventListener('submit',ev=>{
 ev.preventDefault();
 run(async()=>{
  const {data,error:e}=await client.auth.signInWithPassword({
   email:$('email').value.trim(),password:$('password').value
  });
  if(e)throw e;
  $('password').value='';
  user=data.user;state();
 });
});
$('signOut').onclick=()=>run(async()=>{
 const {error:e}=await client.auth.signOut();
 if(e)throw e;user=null;currentSecret=null;incoming=null;
 $('qrcode').replaceChildren();$('linkBox').hidden=true;state();
});
$('startPair').onclick=()=>run(async()=>{
 if(!user)throw Error('Sign in first');
 const name=$('desktopName').value.trim();
 if(!name||name.length>60)throw Error('Enter a device name');
 const code=await rpc('itamar_begin_pair',{
  p_name:name,p_chats:$('wantChats').checked,
  p_contacts:$('wantContacts').checked,p_files:false
 });
 if(!/^[0-9a-f]{48}$/.test(code))throw Error('Server did not return a valid pairing code.');
 currentSecret=code;
 const base=(location.hostname==='127.0.0.1'||location.hostname==='localhost')?
   'https://itamaros-web-emulator.onrender.com/phone-link.html':
   location.origin+location.pathname;
 const link=base+'#pair='+code;
 const root=$('qrcode');root.replaceChildren();
 if(typeof window.QRCode!=='function')throw Error('Local QR library unavailable');
 new window.QRCode(root,{text:link,width:240,height:240,correctLevel:window.QRCode.CorrectLevel.M});
 $('linkBox').hidden=false;
 $('copyLink').onclick=async()=>{
   if(!navigator.clipboard?.writeText)throw Error('Clipboard unavailable on this device');
   await navigator.clipboard.writeText(link);
   $('error').textContent='Link copied. Share only with your own phone.';
 };
 await loadPairs();
});
$('checkPair').onclick=()=>run(loadPairs);
$('refresh').onclick=()=>run(loadPairs);
$('approve').onclick=()=>run(async()=>{
 if(!preview||!incoming)throw Error('Invalid pairing invitation');
 if(!confirm('Pair this phone with your own '+preview.desktop_name+' account?'))return;
 let id=localStorage.getItem('itamaros-phone-device-id');
 if(!id){id=crypto.randomUUID();localStorage.setItem('itamaros-phone-device-id',id)}
 const phoneName=$('phoneName').value.trim();
 if(!phoneName||phoneName.length>60)throw Error('Choose a phone name');
 await rpc('itamar_accept_pair',{p_code:incoming,p_device:id,p_phone_name:phoneName});
 $('pairInfo').textContent='Paired. Your selected ItamarOS data can sync when its backend is enabled.';
 incoming=null;preview=null;$('phone').hidden=true;$('desktop').hidden=false;
 await loadPairs();
});
$('decline').onclick=()=>{incoming=null;preview=null;$('phone').hidden=true;$('desktop').hidden=false};
client.auth.onAuthStateChange((_ev,session)=>{if(!session){user=null;state()}});
run(session)();
})();