'use strict';
const desktop=window.itamarConnect;
const $=id=>document.getElementById(id);
let self=null,rooms=[],current=null,sessionEnd=0;
let pairingTimer=null,updatesTimer=null,roomTimer=null,busyMessages=false;
const setStatus=(text)=>{$('status').textContent=text||''};
const safe=fn=>async(...args)=>{try{await fn(...args)}catch(e){setStatus(e.message||'Something went wrong')}};
function show(which){
 for(const id of ['login','profileSetup','layout'])$(id).hidden=id!==which;
 $('logout').hidden=which==='login';
}
function stopPairing(){if(pairingTimer){clearInterval(pairingTimer);pairingTimer=null}}
function stopUpdates(){if(updatesTimer)clearInterval(updatesTimer);if(roomTimer)clearInterval(roomTimer);updatesTimer=null;roomTimer=null}
function api(method,route,body){return desktop.api(method,route,body)}
async function startPair(){
 stopUpdates();stopPairing();current=null;self=null;
 show('login');setStatus('Creating a secure one-time QR…');
 const pair=await desktop.start();
 $('qrImage').src=pair.qr;$('qrImage').hidden=false;
 $('pairCode').textContent='Code: '+pair.shortCode;
 $('expiry').textContent='Scan before '+new Date(pair.expiresAt).toLocaleTimeString();
 setStatus('Scan on a phone signed in to ItamarConnect, then tap Approve.');
 let polling=false;
 pairingTimer=setInterval(async()=>{
  if(polling)return;
  polling=true;
  try{
   const status=await desktop.poll();
   if(status.status==='approved'){
    stopPairing();
    sessionEnd=status.expiresAt;
    self={id:status.userId};
    await loadAccount();
   }
  }catch(e){
   stopPairing();setStatus(e.message||'Pairing failed.');
  }finally{polling=false}
 },2300);
}
async function loadAccount(){
 if(!self)return;
 const profiles=await api('GET','/rest/v1/itamar_profiles?id=eq.'+self.id+'&select=id,username,display_name');
 const profile=Array.isArray(profiles)?profiles[0]:null;
 if(!profile){show('profileSetup');setStatus('Verify your name before sending messages.');return}
 self={...self,...profile};
 $('selfUser').textContent='Signed in as @'+self.username;
 show('layout');await refreshRooms();setStatus('Connected. This computer session expires '+new Date(sessionEnd).toLocaleTimeString()+'.');
 stopUpdates();
 updatesTimer=setInterval(()=>{if(self)safe(refreshRooms)()},25000);
 roomTimer=setInterval(()=>{if(self&&current)safe(refreshMessages)()},4500);
}
async function refreshRooms(){
 if(!self)return;
 const data=await api('POST','/rest/v1/rpc/itamar_my_rooms_v2',{});
 rooms=Array.isArray(data)?data:[];
 const root=$('roomList');root.replaceChildren();
 if(!rooms.length)root.textContent='No conversations yet. Start one below.';
 for(const room of rooms){
  const button=document.createElement('button');
  button.className='room'+(current?.id===room.id?' active':'');
  button.textContent=room.title+' · '+room.kind;
  button.onclick=()=>safe(()=>openRoom(room))();
  root.append(button);
 }
 if(current&&!rooms.some(r=>r.id===current.id)){
  current=null;$('roomTitle').textContent='Choose a conversation';
  $('messages').replaceChildren();$('sendForm').hidden=true;
 }
}
async function openRoom(room){
 current=room;$('roomTitle').textContent=room.title;
 $('sendForm').hidden=room.kind==='channel'&&room.owner_id!==self.id;
 await refreshRooms();await refreshMessages();
}
async function refreshMessages(){
 if(!current||!self||busyMessages)return;
 busyMessages=true;const room=current;
 try{
  const list=await api('GET','/rest/v1/itamar_messages?room_id=eq.'+encodeURIComponent(room.id)+
    '&select=id,body,created_at,sender_id,deleted_at&order=created_at.asc&limit=100');
  if(current?.id!==room.id)return;
  const root=$('messages');
  const nearBottom=root.scrollHeight-root.scrollTop-root.clientHeight<80;
  root.replaceChildren();
  for(const msg of Array.isArray(list)?list:[]){
   const bubble=document.createElement('div');
   bubble.className='message'+(msg.sender_id===self.id?' mine':'');
   const body=document.createElement('span');
   body.textContent=msg.deleted_at?'Message deleted':msg.body;
   const time=document.createElement('small');
   time.textContent=(msg.sender_id===self.id?'You':'Member')+' · '+new Date(msg.created_at).toLocaleString();
   bubble.append(body,time);root.append(bubble);
  }
  if(nearBottom)root.scrollTop=root.scrollHeight;
 }finally{busyMessages=false}
}
$('newQR').addEventListener('click',safe(startPair));
$('logout').addEventListener('click',safe(async()=>{
 stopPairing();stopUpdates();await desktop.logout();
 self=null;current=null;show('login');
 $('qrImage').hidden=true;$('pairCode').textContent='';setStatus('Signed out.');
}));
$('refresh').addEventListener('click',safe(refreshRooms));
$('profileForm').addEventListener('submit',safe(async event=>{
 event.preventDefault();
 const name=$('displayName').value.trim(),username=$('username').value.toLowerCase().trim();
 if(!name||!/^[a-z0-9_.]{3,24}$/.test(username))throw Error('Enter a name and valid username.');
 await api('POST','/rest/v1/itamar_profiles',{
  id:self.id,display_name:name,username,about:''
 });
 await loadAccount();
}));
$('newChat').addEventListener('submit',safe(async event=>{
 event.preventDefault();
 const title=$('chatTitle').value.trim(),username=$('chatUser').value.trim().replace(/^@/,'').toLowerCase();
 if(!title||!/^[a-z0-9_.]{3,24}$/.test(username))throw Error('Enter a title and valid @username.');
 await api('POST','/rest/v1/rpc/itamar_create_room',{p_kind:'chat',p_title:title,p_username:username});
 $('chatTitle').value='';$('chatUser').value='';
 await refreshRooms();setStatus('Chat created.');
}));
$('sendForm').addEventListener('submit',safe(async event=>{
 event.preventDefault();
 if(!self||!current)return;
 const body=$('messageText').value.trim();if(!body)return;
 await api('POST','/rest/v1/itamar_messages',{room_id:current.id,sender_id:self.id,body});
 $('messageText').value='';await refreshMessages();
}));
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&self)safe(refreshMessages)()});
show('login');
setStatus('Click Generate QR code to pair your computer.');
