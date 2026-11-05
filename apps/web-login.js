(()=>{'use strict';
const url='https://slqjkysinhfkqjoigfuz.supabase.co';
const key='sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts';
const root=document.getElementById('itamar-login-gate'),form=document.getElementById('itamar-login-form'),status=document.getElementById('itamar-login-status'),email=document.getElementById('itamar-login-email'),password=document.getElementById('itamar-login-password'),logout=document.getElementById('itamar-logout'),google=document.getElementById('itamar-google-login');
const storageKey='itamaros.web.session.v2',pkceKey='itamaros.web.oauth.pkce';
let session=null;
function show(authorized){root.hidden=authorized;logout.hidden=!authorized;document.body.classList.toggle('itamar-auth-required',!authorized);if(!authorized)password.value=''}
function save(data){session=data;try{if(data)localStorage.setItem(storageKey,JSON.stringify(data));else localStorage.removeItem(storageKey)}catch{}show(!!data)}
async function api(path,token,body){const response=await fetch(url+path,{method:body?'POST':'GET',headers:{'apikey':key,'Authorization':'Bearer '+(token||key),'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,cache:'no-store'});const data=await response.json().catch(()=>({}));if(!response.ok)throw Error(data.msg||data.error_description||data.message||data.error||'Authentication failed');return data}
function randomString(){const bytes=crypto.getRandomValues(new Uint8Array(32));return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('')}
function base64url(bytes){return btoa(String.fromCharCode(...bytes)).replace(/\\+/g,'-').replace(/\\//g,'_').replace(/=+$/,'')}
async function beginGoogle(){
  if(!crypto.subtle){status.textContent='Google sign-in requires a secure HTTPS connection.';return}
  google.disabled=true;status.textContent='Opening Google…';
  try{
    const verifier=randomString();
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier));
    sessionStorage.setItem(pkceKey,verifier);
    const redirect=location.origin+location.pathname;
    const params=new URLSearchParams({provider:'google',redirect_to:redirect,code_challenge:base64url(new Uint8Array(digest)),code_challenge_method:'s256'});
    location.assign(url+'/auth/v1/authorize?'+params.toString());
  }catch{status.textContent='Could not start Google sign-in.';google.disabled=false}
}
async function oauthCallback(){
 const params=new URLSearchParams(location.search);
 if(!params.has('code')&&!params.has('error')&&!params.has('error_description'))return false;
 const code=params.get('code'),verifier=sessionStorage.getItem(pkceKey);
 history.replaceState(null,'',location.pathname+location.hash);
 if(!code){status.textContent='Google sign-in was cancelled or denied.';return true}
 if(!verifier){status.textContent='Sign-in session expired. Please try Google again.';return true}
 try{
  const data=await api('/auth/v1/token?grant_type=pkce',null,{auth_code:code,code_verifier:verifier});
  if(!data.access_token)throw Error('Missing access token');
  save(data);status.textContent='';
 }catch{status.textContent='Google sign-in failed. Check the OAuth redirect configuration.'}
 finally{sessionStorage.removeItem(pkceKey)}
 return true;
}
async function check(){
 if(await oauthCallback())return;
 try{
  const saved=JSON.parse(localStorage.getItem(storageKey)||'null');
  if(saved?.access_token){
   const expiresAt=saved.expires_at||((saved.expires_in&&saved.saved_at)?saved.saved_at+saved.expires_in:0);
   if(expiresAt&&Date.now()/1000>expiresAt-60&&saved.refresh_token){
    const refreshed=await api('/auth/v1/token?grant_type=refresh_token',null,{refresh_token:saved.refresh_token});
    save({...refreshed,saved_at:Math.floor(Date.now()/1000),expires_at:Math.floor(Date.now()/1000)+(refreshed.expires_in||3600)});return;
   }
   const user=await api('/auth/v1/user',saved.access_token);
   if(user?.id){save(saved);return}
  }
 }catch{}
 save(null);
}
form.addEventListener('submit',async e=>{
 e.preventDefault();const button=form.querySelector('button[type=submit]');button.disabled=true;status.textContent='Signing in…';
 try{const data=await api('/auth/v1/token?grant_type=password',null,{email:email.value.trim(),password:password.value});if(!data.access_token)throw Error('No access token');save({...data,saved_at:Math.floor(Date.now()/1000)});status.textContent='';password.value=''}
 catch{status.textContent='Could not sign in. Check your email and password.'}
 finally{button.disabled=false}
});
google?.addEventListener('click',beginGoogle);
logout.addEventListener('click',async()=>{const token=session?.access_token;save(null);if(token)try{await api('/auth/v1/logout',token,{})}catch{}});
show(false);void check();
})();