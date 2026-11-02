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
  auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:true,storageKey:'itamaros-connect-web-auth'}
});
let user=null,rooms=[],current=null;
let pendingPassword='',pendingAvatar=null,avatarPreviewURL=null;
let deviceSync=localStorage.getItem('itamaros-connect-device-sync')!=='off';
let pendingUsername='',authMode='signup',profileReady=false;
let messageChannel=null;
function stopWatching(){
 if(messageChannel){void client.removeChannel(messageChannel);messageChannel=null}
}
function watchCurrentRoom(){
 stopWatching();
 if(!current||!user||!deviceSync)return;
 const id=current.id;
 messageChannel=client.channel('itamaros-room-'+id)
  .on('postgres_changes',{event:'INSERT',schema:'public',table:'itamar_messages',filter:'room_id=eq.'+id},
    ()=>{if(current?.id===id)safe(loadMessages)();})
  .subscribe();
}
$('deviceSync').checked=deviceSync;
function requireSync(){
 if(!deviceSync)throw Error('Cloud sync is disabled on this device. Enable it in Settings to open messages.');
}
function clearCloudView(){
 stopWatching();
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
 if(user&&!profileReady&&name!=='profile'){name='profile';setStatus('Complete your profile before using Connect.');}
 if(!deviceSync&&name!=='settings'&&!(name==='profile'&&!profileReady)){name='settings';setStatus('Sync is off on this device. Turn it on to show cloud conversations.');}
 for(const el of document.querySelectorAll('[id^="tab-"]'))el.hidden=el.id!=='tab-'+name;
 for(const el of document.querySelectorAll('[data-tab]'))el.dataset.selected=el.dataset.tab===name?'true':'false';
 if(name==='updates')safe(loadUpdates)();
}
function requireProfile(){
 if(!user)throw Error('Sign in to use Connect.');
 if(!profileReady)throw Error('Complete your profile before using Connect.');
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
 watchCurrentRoom();
}
async function loadMessages(){
 requireSync();
 if(!current)return;
 const requestedRoom=current.id;
 const {data,error}=await client.from('itamar_messages')
  .select('id,room_id,sender_id,body,created_at,deleted_at,is_view_once')
  .eq('room_id',current.id).order('created_at',{ascending:true}).limit(100);
 if(error)throw error;
 if(!current||current.id!==requestedRoom)return;
 const root=$('messages');root.replaceChildren();
 for(const m of data||[]){
  const wrap=document.createElement('div');wrap.className='msg'+(m.sender_id===user.id?' mine':'');
  const label=document.createElement('small');label.textContent=(m.sender_id===user.id?'You':'Member')+' · '+new Date(m.created_at).toLocaleString();
  const txt=document.createElement('div');txt.textContent=m.deleted_at?'Message deleted':m.body;
  wrap.append(label,txt);
  if(m.sender_id!==user.id){
   const controls=document.createElement('div');controls.className='row';
   const report=document.createElement('button');report.type='button';report.textContent='Report';
   report.onclick=()=>safe(async()=>{
    const reason=window.prompt('Reason: Spam, Harassment, Threats or Other','Spam');
    if(reason===null)return;
    const choices={spam:'Spam',harassment:'Harassment',threats:'Threats',other:'Other'};
    const selected=choices[reason.trim().toLowerCase()];
    if(!selected)throw Error('Choose Spam, Harassment, Threats or Other');
    const {error}=await client.rpc('itamar_report_message',{p_message:m.id,p_reason:selected,p_detail:''});
    if(error)throw error;
    setStatus('Report saved. Moderator review is not yet configured.');
   })();
   const block=document.createElement('button');block.type='button';block.textContent='Block';
   block.onclick=()=>safe(async()=>{
    if(!window.confirm('Block this account and hide its messages?'))return;
    const {error}=await client.from('itamar_blocks').insert({blocker_id:user.id,blocked_id:m.sender_id});
    if(error&&error.code!=='23505')throw error;
    await loadMessages();await showBlocks();setStatus('Account blocked.');
   })();
   controls.append(report,block);wrap.append(controls);
  }
  root.append(wrap)
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
async function showBlocks(){
 if(!user||!deviceSync)return;
 const root=$('blockedUsers');if(!root)return;
 const {data,error}=await client.from('itamar_blocks').select('blocked_id').eq('blocker_id',user.id).limit(100);
 if(error)throw error;
 root.replaceChildren();
 if(!data?.length){root.textContent='No blocked accounts.';return}
 for(const item of data){
  const line=document.createElement('div');line.className='room';
  const title=document.createElement('span');title.textContent='Blocked account';
  const undo=document.createElement('button');undo.type='button';undo.textContent='Unblock';
  undo.onclick=()=>safe(async()=>{
   const {error}=await client.from('itamar_blocks').delete().eq('blocker_id',user.id).eq('blocked_id',item.blocked_id);
   if(error)throw error;
   await showBlocks();if(current)await loadMessages();
  })();
  line.append(title,undo);root.append(line);
 }
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
 if(!data.user.email_confirmed_at){await client.auth.signOut();user=null;$('auth').hidden=false;$('app').hidden=true;setStatus('Confirm your email before signing in.',true);return}
 user=data.user;$('auth').hidden=true;$('app').hidden=false;
 const {data:profile,error:profileError}=await client.from('itamar_profiles').select('id').eq('id',user.id).maybeSingle();
 if(profileError)throw profileError;
 profileReady=Boolean(profile);
 if(!profileReady){
  clearCloudView();
  const proposed=pendingUsername||data.user.user_metadata?.preferred_username||'';
  $('username').value=proposed;
  $('displayName').value=proposed;
  selectTab('profile');
  setStatus('Email confirmed. Save your username to finish your profile.');
  return;
 }
 if(deviceSync){await refreshRooms();await loadProfile();await showBlocks();}
 else {clearCloudView();selectTab('settings');}
}
function setAuthMode(mode){
 authMode=mode==='signin'?'signin':'signup';
 const signup=authMode==='signup';
 $('signupFields').hidden=!signup;
 $('signupPhoneField').hidden=!signup;
 $('signinFields').hidden=signup;
 $('authSubmit').textContent=signup?'Create account — send confirmation email':'Sign in';
 $('phone').required=false;
 $('signinIdentifier').required=!signup;
 $('signinPassword').required=!signup;
 $('signupEmail').required=signup;
 $('signupPassword').required=signup;
 $('signupUsername').required=signup;
 $('signupAvatar').required=false;
 $('authTitle').textContent=signup?'Create your ItamarOS account':'Sign in to ItamarOS';
 $('authHelp').textContent=signup?
  'Username, email and password are required (*). Phone and profile photo are optional. Confirm your email to activate your account.':
  'Enter your ItamarOS email address and password, or approve QR login inside Cloud Climb.';
 $('signupMode').classList.toggle('primary',signup);
 $('signinMode').classList.toggle('primary',!signup);
}
$('signupMode').onclick=()=>setAuthMode('signup');
$('signinMode').onclick=()=>setAuthMode('signin');
$('useDefaultAvatar').addEventListener('change',()=>{
 if($('useDefaultAvatar').checked){
  pendingAvatar=null;
  $('signupAvatar').value='';
  $('avatarPreview').hidden=true;
  if(avatarPreviewURL){URL.revokeObjectURL(avatarPreviewURL);avatarPreviewURL=null;}
 }
 $('signupAvatar').required=false;
});
setAuthMode('signup');
$('signupAvatar').addEventListener('change',()=>{
 const selected=$('signupAvatar').files?.[0]||null;
 if(avatarPreviewURL){URL.revokeObjectURL(avatarPreviewURL);avatarPreviewURL=null}
 pendingAvatar=null;$('avatarPreview').hidden=true;
 if(!selected)return;
 if(!['image/jpeg','image/png','image/webp'].includes(selected.type) || selected.size>3*1024*1024){
  $('signupAvatar').value='';message('Choose a JPG, PNG or WebP photo under 3 MB.');return;
 }
 pendingAvatar=selected;
 $('useDefaultAvatar').checked=false;
 $('signupAvatar').required=false;
 avatarPreviewURL=URL.createObjectURL(selected);
 $('avatarPreview').src=avatarPreviewURL;$('avatarPreview').hidden=false;
});
$('smsForm').addEventListener('submit',safe(async e=>{
 e.preventDefault();
 if(authMode==='signup'){
  const username=$('signupUsername').value.trim().toLowerCase();
  const email=$('signupEmail').value.trim().toLowerCase();
  const password=$('signupPassword').value;
  const phone=$('phone').value.trim();
  if(!/^[a-z0-9_.]{3,24}$/.test(username))
   throw Error('Username: 3–24 lowercase letters, numbers, _ or .');
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254)
   throw Error('Enter a valid email.');
  if(password.length<8)throw Error('Choose a password of at least 8 characters.');
  if(phone && !/^\+[1-9]\d{7,14}$/.test(phone))
   throw Error('Optional phone must use +country-code format, e.g. +972...');
  const {data,error}=await client.auth.signUp({
   email,password,
   options:{
    emailRedirectTo:window.location.origin+window.location.pathname,
    data:{preferred_username:username,...(phone?{unverified_contact_phone:phone}:{})}
   }
  });
  if(error)throw error;
  pendingUsername=username;
  // Username survives in private Auth metadata across email-confirmation redirects.
  // A selected optional photo can be added after sign-in from the Profile tab.
  $('signupPassword').value='';
  if(data?.session){await client.auth.signOut();}
  setStatus('Check your inbox and confirm the email address. Then return here and sign in. No SMS is needed.');
  return;
 }
 const email=$('signinIdentifier').value.trim().toLowerCase();
 const password=$('signinPassword').value;
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!password)
  throw Error('Enter your email and password.');
 const {error}=await client.auth.signInWithPassword({email,password});
 if(error)throw error;
 $('signinPassword').value='';
 await drawSession();
 setStatus('Signed in to your ItamarOS account.');
}));
async function applyPendingAvatar(){
 if(!pendingAvatar||!user)return;
 const currentAvatar=pendingAvatar;
 const fileType=currentAvatar.type;
 const extension={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[fileType];
 const path='profiles/'+user.id+'/'+crypto.randomUUID()+'.'+extension;
 const {error:uploadError}=await client.storage.from('itamar-connect-avatars')
  .upload(path,currentAvatar,{contentType:fileType,upsert:false});
 if(uploadError)throw uploadError;
 const {error:prefsError}=await client.rpc('itamar_set_profile_prefs',{
   p_avatar:path,p_receipts:true
 });
 if(prefsError)throw prefsError;
 pendingAvatar=null;$('signupAvatar').value='';$('avatarPreview').hidden=true;
 if(avatarPreviewURL){URL.revokeObjectURL(avatarPreviewURL);avatarPreviewURL=null}
}
$('forgotPassword').onclick=()=>{
 $('forgotPasswordForm').hidden=false;
 $('recoveryEmail').value=$('signinIdentifier').value.trim();
};
$('cancelForgot').onclick=()=>{$('forgotPasswordForm').hidden=true;};
$('forgotPasswordForm').addEventListener('submit',safe(async e=>{
 e.preventDefault();
 const email=$('recoveryEmail').value.trim();
 const {error}=await client.auth.resetPasswordForEmail(email,{
  redirectTo:window.location.origin+window.location.pathname
 });
 if(error)throw error;
 $('forgotPasswordForm').hidden=true;
 setStatus('If that account exists, a password reset link has been sent by email.');
}));
$('resetPasswordForm').addEventListener('submit',safe(async e=>{
 e.preventDefault();
 const value=$('newPassword').value;
 if(value.length<8)throw Error('Password must contain at least 8 characters.');
 const {error}=await client.auth.updateUser({password:value});
 if(error)throw error;
 $('newPassword').value='';$('passwordRecovery').hidden=true;
 setStatus('Password updated successfully.');
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
$('logout').onclick=safe(async()=>{stopWatching();const {error}=await client.auth.signOut();if(error)throw error;current=null;rooms=[];await drawSession();setStatus('Signed out.')});
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
 e.preventDefault();
 if(!user)throw Error('Sign in before editing your profile.');
 const username=$('username').value.toLowerCase().trim();
 if(!/^[a-z0-9_.]{3,24}$/.test(username))throw Error('Username must have 3–24 letters, digits, underscore or dot.');
 const {error}=await client.from('itamar_profiles').upsert({
  id:user.id,display_name:$('displayName').value.trim(),username,about:$('bio').value.trim()
 },{onConflict:'id'});
 if(error)throw error;
 profileReady=true;
 await applyPendingAvatar();
 if(deviceSync)await refreshRooms();
 setStatus('Profile saved.');
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
client.auth.onAuthStateChange((event,session)=>{
 if(event==='PASSWORD_RECOVERY'){$('passwordRecovery').hidden=false;}
 if(!session){stopWatching();user=null;profileReady=false;$('app').hidden=true;$('auth').hidden=false;}
});
// RLS-protected Realtime is primary; polling heals reconnects and new room invitations.
window.setInterval(()=>{
 if(!user||!deviceSync||document.visibilityState!=='visible')return;
 if(current)safe(loadMessages)();else safe(refreshRooms)();
},12000);
window.setInterval(()=>{
 if(user&&deviceSync&&document.visibilityState==='visible')safe(refreshRooms)();
},30000);
safe(drawSession)();
})();