/* ItamarConnect Web: a real authenticated client only if backend config exists.
   No demo account impersonation, no message/contact upload without explicit action. */
(()=>{'use strict';
const $=id=>document.getElementById(id);
const config=window.ITAMAR_CONNECT||{};
const configured=typeof config.url==='string'&&/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(config.url)&&
  typeof config.publishableKey==='string'&&config.publishableKey.length>10;
const sd=window.supabase;
if(!configured||!sd?.createClient){$('offline').hidden=false;return}
$('offline').hidden=true;
const client=sd.createClient(config.url,config.publishableKey,{
  auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:false,storageKey:'itamaros-connect-web-auth'}
});
let user=null,rooms=[],current=null,creating=false,register=false;
let deviceSync=localStorage.getItem('itamaros-connect-device-sync')!=='off';
let pendingPhone='';
$('deviceSync').checked=deviceSync;
function requireSync(){
 if(!deviceSync)throw Error('Cloud sync is disabled on this device. Enable it in Settings to open messages.');
}
function clearCloudView(){
 rooms=[];current=null;
 for(const id of ['rooms','groups','channels','messages','updates','discovered'])$(id)?.replaceChildren();
 $('threadTitle').textContent='Cloud sync is off';
 $('sendForm').hidden=true;
}
const setStatus=(text,error=false)=>{const node=$('status');node.textContent=text||'';node.style.color=error?'#a32d33':'#125b3e'};
const message=(text)=>setStatus(String(text||'').slice(0,300),true);
const safe=(fn)=>async (...args)=>{try{await fn(...args)}catch(error){message(error?.message||'Operation failed')}};
const draw=(where,title,subtitle,act)=>{
 const row=document.createElement('div');row.className='room';
 const label=document.createElement('button');label.type='button';label.textContent=title;label.onclick=act;row.append(label);
 if(subtitle){const text=document.createElement('small');text.textContent=subtitle;row.append(text)}
 where.append(row);
};
function selectTab(name){
 if(!deviceSync&&name!=='settings'){name='settings';setStatus('Sync is off on this device. Turn it on to show cloud conversations.');}
 for(const el of document.querySelectorAll('[id^="tab-"]'))el.hidden=el.id!=='tab-'+name;
 for(const el of document.querySelectorAll('[data-tab]'))el.dataset.selected=el.dataset.tab===name?'true':'false';
 if(name==='updates')safe(loadUpdates)();
}
function requireProfile(){
 if(!user)throw Error('Sign in to use Connect.');
}
async function refreshRooms(){
 requireProfile();requireSync();
 const {data,error}=await client.rpc('itamar_my_rooms_v2');
 if(error)throw error;
 rooms=data||[];
 for(const [element,kind] of [['rooms','chat'],['groups','group'],['channels','channel']]){
  const root=$(element);root.replaceChildren();
  const items=rooms.filter(r=>r.kind===kind);
  if(!items.length){const msg=document.createElement('p');msg.className='muted';msg.textContent='Nothing here yet.';root.append(msg)}
  for(const room of items){
    const wrap=document.createElement('div');wrap.className='room';
    const title=document.createElement('button');title.type='button';title.textContent=room.title;
    title.onclick=()=>safe(openRoom)(room);wrap.append(title);
    const mute=document.createElement('button');mute.type='button';mute.textContent=room.muted?'Unmute':'Mute';
    mute.onclick=()=>safe(async()=>{const {error}=await client.rpc('itamar_set_mute',{p_room:room.id,p_muted:!room.muted});if(error)throw error;await refreshRooms()})();
    wrap.append(mute);root.append(wrap);
  }
 }
}
async function openRoom(room){
 current=room;$('threadTitle').textContent=room.title;
 if(room.kind==='chat')selectTab('chats');
 // For groups/channels, use the same thread pane in the Chats tab.
 else selectTab('chats');
 $('sendForm').hidden=room.kind==='channel'&&room.owner_id!==user.id;
 await loadMessages();
}
async function loadMessages(){
 requireSync();
 if(!current)return;
 const {data,error}=await client.from('itamar_messages')
  .select('id,room_id,sender_id,body,created_at,deleted_at,is_view_once')
  .eq('room_id',current.id).order('created_at',{ascending:true}).limit(100);
 if(error)throw error;
 const root=$('messages');root.replaceChildren();
 for(const m of data||[]){
  const wrap=document.createElement('div');wrap.className='msg'+(m.sender_id===user.id?' mine':'');
  const label=document.createElement('small');label.textContent=(m.sender_id===user.id?'You':'Member')+' · '+new Date(m.created_at).toLocaleString();
  const txt=document.createElement('div');txt.textContent=m.deleted_at?'Message deleted':m.body;
  wrap.append(label,txt);root.append(wrap)
 }
 root.scrollTop=root.scrollHeight;
 const {error:ackError}=await client.rpc('itamar_ack_messages',{p_room:current.id,p_opened:true});
 if(ackError)console.info('Delivery acknowledgements unavailable');
}
async function loadUpdates(){
 requireProfile();requireSync();
 const {data,error}=await client.rpc('itamar_my_updates');if(error)throw error;
 const root=$('updates');root.replaceChildren();
 for(const item of data||[]){
  const wrap=document.createElement('p');
  const title=document.createElement('strong');title.textContent=item.title+': ';
  const text=document.createElement('span');text.textContent=item.body;
  wrap.append(title,text);root.append(wrap)
 }
 if(!root.childNodes.length)root.textContent='No unmuted updates yet.';
}
async function loadProfile(){
 requireSync();
 if(!user)return;
 const {data,error}=await client.from('itamar_profiles')
 .select('display_name,username,about').eq('id',user.id).maybeSingle();
 if(error)throw error;
 $('displayName').value=data?.display_name||'';$('username').value=data?.username||'';
 $('bio').value=data?.about||'';
}
async function drawSession(){
 const {data,error}=await client.auth.getUser();
 if(error||!data?.user){user=null;$('auth').hidden=false;$('app').hidden=true;return}
 user=data.user;$('auth').hidden=true;$('app').hidden=false;
 if(deviceSync){await refreshRooms();await loadProfile();}
 else {clearCloudView();selectTab('settings');}
}
$('authForm').addEventListener('submit',safe(async(event)=>{
 event.preventDefault();
 const email=$('email').value.trim(),password=$('password').value;
 const {data,error}=register?await client.auth.signUp({email,password}):
   await client.auth.signInWithPassword({email,password});
 if(error)throw error;
 $('password').value='';
 if(!data.session){setStatus('Check your email and confirm your account, then sign in.');return}
 await drawSession();setStatus('Signed in securely.');
}));
$('swapAuth').onclick=()=>{register=!register;$('authTitle').textContent=register?'Create an account':'Sign in';$('swapAuth').textContent=register?'Already have an account?':'Create an account'};
$('smsForm').addEventListener('submit',safe(async e=>{
 e.preventDefault();
 const phone=$('phone').value.trim();
 if(!/^\+[1-9]\d{7,14}$/.test(phone))throw Error('Enter your own number in international format, such as +972...');
 const {error}=await client.auth.signInWithOtp({phone});
 if(error)throw error;
 pendingPhone=phone;
 $('smsVerifyForm').hidden=false;
 setStatus('Verification code requested. Check the phone you own. Do not share this code.');
}));
$('smsVerifyForm').addEventListener('submit',safe(async e=>{
 e.preventDefault();
 if(!pendingPhone)throw Error('Request a new code.');
 const code=$('smsCode').value.trim();
 if(!/^\d{4,8}$/.test(code))throw Error('Enter the SMS verification code.');
 const {data,error}=await client.auth.verifyOtp({phone:pendingPhone,token:code,type:'sms'});
 if(error)throw error;
 if(!data?.session)throw Error('Verification was not completed.');
 $('smsCode').value='';pendingPhone='';$('smsVerifyForm').hidden=true;
 await drawSession();setStatus('Phone confirmed and signed in.');
}));
$('deviceSync').addEventListener('change',safe(async e=>{
 deviceSync=Boolean(e.target.checked);
 localStorage.setItem('itamaros-connect-device-sync',deviceSync?'on':'off');
 if(deviceSync&&user){
   await refreshRooms();await loadProfile();
   setStatus('Sync enabled for this browser or tablet.');
 }else{
   clearCloudView();selectTab('settings');
   setStatus('Sync disabled here. Existing account messages remain on the server.');
 }
}));
$('refreshDevice').onclick=()=>safe(async()=>{
 if(!deviceSync)throw Error('Enable Sync to refresh messages.');
 await refreshRooms();setStatus('Synced room list refreshed.');
})();
$('logout').onclick=safe(async()=>{const {error}=await client.auth.signOut();if(error)throw error;current=null;rooms=[];await drawSession();setStatus('Signed out.')});
$('sendForm').addEventListener('submit',safe(async(event)=>{
 event.preventDefault();requireSync();if(!current)return;
 const body=$('messageBody').value.trim();if(!body)return;
 const {error}=await client.from('itamar_messages').insert({room_id:current.id,sender_id:user.id,body});
 if(error)throw error;$('messageBody').value='';await loadMessages();
}));
async function createRoom(kind,title,username){
 requireProfile();requireSync();
 const {error}=await client.rpc('itamar_create_room',{
   p_kind:kind,p_title:title,p_username:username||null
 });if(error)throw error;await refreshRooms();setStatus('Conversation created.');
}
$('newChat').addEventListener('submit',safe(async(e)=>{
 e.preventDefault();await createRoom('chat',$('chatName').value.trim(),$('chatUser').value.trim());
}));
$('newChannel').addEventListener('submit',safe(async(e)=>{
 e.preventDefault();await createRoom('channel',$('channelTitle').value.trim(),null);
}));
$('newGroup').addEventListener('submit',safe(async(e)=>{
 e.preventDefault();requireSync();const names=$('groupUsers').value.split(',').map(x=>x.trim().replace(/^@/,'')).filter(Boolean);
 if(!names.length)throw Error('Enter at least one member username');
 const {error}=await client.rpc('itamar_create_group',{p_title:$('groupTitle').value.trim(),p_usernames:names});
 if(error)throw error;await refreshRooms();setStatus('Group created.');
}));
$('profileForm').addEventListener('submit',safe(async(e)=>{
 e.preventDefault();requireProfile();requireSync();
 const username=$('username').value.toLowerCase().trim();
 if(!/^[a-z0-9_.]{3,24}$/.test(username))throw Error('Username must have 3–24 letters, digits, underscore or dot.');
 const {error}=await client.from('itamar_profiles').upsert({
  id:user.id,display_name:$('displayName').value.trim(),username,about:$('bio').value.trim()
 },{onConflict:'id'});
 if(error)throw error;setStatus('Profile saved.');
}));
$('discover').onclick=safe(async()=>{
 const {data,error}=await client.from('itamar_rooms')
  .select('id,title').eq('kind','channel').order('created_at',{ascending:false}).limit(50);
 if(error)throw error;const root=$('discovered');root.replaceChildren();
 for(const c of data||[])draw(root,c.title,'Join public channel',()=>safe(async()=>{
  const {error}=await client.rpc('itamar_join_channel',{p_room:c.id});if(error)throw error;await refreshRooms();
 })());
});
$('reloadUpdates').onclick=()=>safe(loadUpdates)();
for(const button of document.querySelectorAll('[data-tab]'))button.onclick=()=>selectTab(button.dataset.tab);
client.auth.onAuthStateChange((_event,session)=>{if(!session){user=null;$('app').hidden=true;$('auth').hidden=false}});
safe(drawSession)();
})();