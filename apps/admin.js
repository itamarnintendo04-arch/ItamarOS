(()=>{'use strict';
const $=id=>document.getElementById(id);
const cfg=window.ITAMAR_CONNECT||{};
const allowed=/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(cfg.url||'');
if(!allowed||!cfg.publishableKey||!window.supabase?.createClient){
 $('status').textContent='ItamarOS account server is not configured.';return;
}
const client=window.supabase.createClient(cfg.url,cfg.publishableKey,{
 auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false,storageKey:'itamaros-connect-web-auth'}
});
let invitation='',page=1,users=[],hasMore=false,busy=false;
const status=m=>{$('status').textContent=String(m||'').slice(0,350)};
async function invoke(body){
 const {data,error}=await client.functions.invoke('itamar-admin-console',{body});
 if(error)throw Error(data?.error||error.message||'Not authorized');
 if(data?.error)throw Error(data.error);
 return data;
}
function element(tag,text){
 const node=document.createElement(tag);node.textContent=text;return node;
}
async function adjustBadge(u){
 if(busy)return;
 const next=u.badge==='blue'?null:'blue';
 if(!window.confirm((next?'Award blue verified badge to ':'Remove blue badge from ')+(u.email||u.id)+'?'))return;
 busy=true;
 try{
  await invoke({action:'set_badge',target_id:u.id,badge:next});
  status(next?'Blue verification awarded.':'Blue verification removed.');
  await refresh();
 }catch(e){status(e.message)}finally{busy=false}
}
function render(){
 const search=$('search').value.trim().toLowerCase();
 const filtered=users.filter(u=>[u.id,u.email,u.display_name,u.username].some(t=>String(t||'').toLowerCase().includes(search)));
 const root=$('users');root.replaceChildren();
 const existingSelection=$('recipient').value;
 $('recipient').replaceChildren();
 for(const u of users){
  const opt=document.createElement('option');
  opt.value=u.id;
  opt.textContent=(u.display_name||u.username||'ItamarOS member')+' · '+u.email;
  $('recipient').append(opt);
 }
 if(users.some(u=>u.id===existingSelection))$('recipient').value=existingSelection;
 for(const u of filtered){
  const item=document.createElement('li');item.className='user';
  if(u.avatar_url){const img=document.createElement('img');img.src=u.avatar_url;img.alt='Profile photo of '+(u.display_name||u.username||'user');item.append(img);}
  const content=document.createElement('div');content.className='user-info';
  const header=document.createElement('strong');header.textContent=u.display_name||u.username||'ItamarOS member';content.append(header);
  if(u.badge==='green'||u.badge==='blue'){
   const b=element('span','✓');b.className='verified '+u.badge;b.title=u.badge==='green'?'Official ItamarOS administrator':'ItamarOS verified member';
   content.append(' ',b);
  }
  content.append(
   element('div','@'+(u.username||'user_'+u.id.slice(0,8))),
   element('div','Email (admin-only): '+u.email),
   element('small','ID: '+u.id+' · '+(u.confirmed?'Email confirmed':'Email unconfirmed'))
  );
  const actions=document.createElement('div');actions.className='user-actions';
  const profile=document.createElement('a');
  profile.href='/profile.html?id='+encodeURIComponent(u.id);
  profile.textContent='View profile';profile.target='_blank';profile.rel='noopener noreferrer';
  actions.append(profile);
  if(u.badge!=='green'){
   const verify=element('button',u.badge==='blue'?'Remove blue ✓':'Give blue ✓');
   verify.type='button';verify.onclick=()=>adjustBadge(u);actions.append(verify);
  }
  const send=element('button','Message');send.type='button';send.onclick=()=>{
   $('recipient').value=u.id;$('messageText').focus();
  };actions.append(send);
  item.append(content,actions);root.append(item);
 }
 if(!filtered.length)root.append(element('li','No matching users on this page.'));
 $('page').textContent='Page '+page;
 $('previous').disabled=page<=1;$('next').disabled=!hasMore;
}
async function refresh(){
 const data=await invoke({action:'list',page});
 users=data.users||[];
 hasMore=Boolean(data.has_more);
 render();
}
async function init(){
 const {data}=await client.auth.getSession();
 if(!data?.session){status('Sign in with your verified administrator account first.');return;}
 try{await refresh();$('login').hidden=true;$('panel').hidden=false;status('Administrator account authorized.');}
 catch(e){status('Administrator authorization unavailable: '+(e?.message||'Unknown error'))}
}
$('search').oninput=render;
$('previous').onclick=async()=>{if(page<=1)return;page--;try{await refresh()}catch(e){page++;status(e.message)}};
$('next').onclick=async()=>{if(!hasMore)return;page++;try{await refresh()}catch(e){page--;status(e.message)}};
$('refresh').onclick=()=>refresh().then(()=>status('Directory refreshed.')).catch(e=>status(e.message));
$('messageForm').onsubmit=async e=>{
 e.preventDefault();if(busy)return;
 const target_id=$('recipient').value,body=$('messageText').value.trim();
 if(!target_id||!body)return;
 if(!window.confirm('Send official in-app message to this one recipient?'))return;
 busy=true;
 try{
  await invoke({action:'send_notice',target_id,body});
  $('messageText').value='';status('Official in-app message saved for the selected user.');
 }catch(err){status(err.message)}finally{busy=false}
};
$('invite').addEventListener('submit',async e=>{
 e.preventDefault();invitation='';$('invitation').hidden=true;
 const email=$('email').value.trim();
 try{
  const result=await invoke({action:'invite',email});
  invitation=result.invite_link;
  $('invitationMessage').value='Subject: Your ItamarOS invitation\n\nHello,\n\nYou have been invited to create an ItamarOS account. Open the private one-time link below and choose your own password:\n\n'+invitation+'\n\nIf you were not expecting this invitation, ignore the message.';
  $('link').textContent='Invitation ready for '+email+'. Send this message only to that person.';
  $('invitation').hidden=false;
  status('Invitation generated. Copy it and send it privately.');
 }catch(err){status(err?.message||'Cannot invite account')}
});
$('copyMessage').onclick=async()=>{
 if(!invitation)return;
 try{await navigator.clipboard.writeText($('invitationMessage').value);status('Invitation email copied. Send privately to the recipient.')}
 catch{status('Clipboard unavailable; copy the message manually.')}
};
$('copy').onclick=async()=>{
 if(!invitation)return;
 try{await navigator.clipboard.writeText(invitation);status('Invitation link copied.')}
 catch{status('Clipboard unavailable; copy the message manually.')}
};
void init();
})();