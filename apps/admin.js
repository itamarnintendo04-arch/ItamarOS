(()=>{'use strict';
const $=id=>document.getElementById(id);
const cfg=window.ITAMAR_CONNECT||{};
const allowed=/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(cfg.url||'');
if(!allowed || !cfg.publishableKey || !window.supabase?.createClient){
 $('status').textContent='ItamarOS account server is not configured.';return;
}
const client=window.supabase.createClient(cfg.url,cfg.publishableKey,{
 auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false,storageKey:'itamaros-connect-web-auth'}
});
let invitation='',session=null;
const status=(message)=>{$('status').textContent=String(message||'').slice(0,500)};
async function invoke(body){
 const {data,error}=await client.functions.invoke('itamar-admin-console',{body});
 if(error)throw Error(data?.error||error.message||'Not authorized');
 if(data?.error)throw Error(data.error);
 return data;
}
async function refresh(){
 const data=await invoke({action:'list',page:1});
 const root=$('users');root.replaceChildren();
 for(const item of data.users||[]){
  const node=document.createElement('li');
  node.textContent=(item.email||'Unlisted email')+' · '+(item.confirmed?'Verified':'Not verified');
  root.append(node);
 }
 if(!root.children.length)root.textContent='No accounts in this page.';
}
async function init(){
 const {data}=await client.auth.getSession();
 session=data?.session;
 if(!session){status('Sign in with your admin account first.');return;}
 try{
  await refresh();$('login').hidden=true;$('panel').hidden=false;
  status('Administrator account verified.');
 }catch(e){status('Admin authorization not available: '+(e?.message||'Unknown error'));}
}
$('refresh').onclick=()=>refresh().then(()=>status('List refreshed.')).catch(e=>status(e.message));
$('invite').addEventListener('submit',async e=>{
 e.preventDefault();
 invitation='';$('invitation').hidden=true;
 const email=$('email').value.trim();
 try{
  const result=await invoke({action:'invite',email});
  invitation=result.invite_link;
  $('invitationMessage').value='Subject: Your ItamarOS invitation\\n\\nHello,\\n\\nYou have been invited to create an ItamarOS account. Open the private one-time link below and choose your own password:\\n\\n'+invitation+'\\n\\nIf you were not expecting this invitation, ignore the message.';
  $('link').textContent='Invitation ready for '+email+'. Send this message only to that person.';
  $('invitation').hidden=false;
  status('Invitation generated. Copy it and send it privately.');
 }catch(err){status(err?.message||'Cannot invite account')}
});
$('copyMessage').onclick=async()=>{
 if(!invitation)return;
 try{await navigator.clipboard.writeText($('invitationMessage').value);status('Invitation email copied. Send privately to the intended recipient.');}
 catch{status('Clipboard unavailable; select and copy the message manually.')}
};
$('copy').onclick=async()=>{
 if(!invitation)return;
 try{await navigator.clipboard.writeText(invitation);status('Invitation link copied.');}
 catch{status('Clipboard unavailable. Use a secure browser to copy this invitation.')}
};
void init();
})();