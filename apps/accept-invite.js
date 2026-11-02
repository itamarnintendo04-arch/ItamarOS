(()=>{'use strict';
const $=id=>document.getElementById(id),cfg=window.ITAMAR_CONNECT||{};
if(!/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(cfg.url||'')||!cfg.publishableKey||!window.supabase){
 $('status').textContent='Account service is not configured.';return;
}
const client=window.supabase.createClient(cfg.url,cfg.publishableKey,{
 auth:{detectSessionInUrl:true,persistSession:true,autoRefreshToken:true,storageKey:'itamaros-connect-web-auth'}
});
const status=s=>{$('status').textContent=s};
async function init(){
 // The provider-signed invite URL is redeemed by the auth client. Never accept a custom PIN.
 const {data,error}=await client.auth.getSession();
 if(error||!data?.session){status('Invitation expired or not yet verified. Request a new link from the administrator.');return;}
 const {data:profile,error:userError}=await client.auth.getUser();
 if(userError||!profile?.user){status('Invitation could not be verified.');return;}
 $('form').hidden=false;
 status('Signed in to a verified invitation session. Choose your own password.');
}
$('form').addEventListener('submit',async e=>{
 e.preventDefault();
 const first=$('password').value,second=$('confirm').value;
 if(first.length<8||first!==second){status('Passwords must match and have at least 8 characters.');return;}
 const {error}=await client.auth.updateUser({password:first});
 if(error){status(error.message);return;}
 $('form').hidden=true;$('password').value='';$('confirm').value='';
 $('openNative').hidden=false;
 status('Password saved. You can now sign in to ItamarOS.');
});
void init();
})();