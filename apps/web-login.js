(()=>{'use strict';
const url='https://slqjkysinhfkqjoigfuz.supabase.co';
const key='sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts';
const root=document.getElementById('itamar-login-gate'),form=document.getElementById('itamar-login-form'),status=document.getElementById('itamar-login-status'),email=document.getElementById('itamar-login-email'),password=document.getElementById('itamar-login-password'),logout=document.getElementById('itamar-logout');
const storageKey='itamaros.web.session.v1';
let session=null;
function show(authorized){root.hidden=authorized;logout.hidden=!authorized;document.body.classList.toggle('itamar-auth-required',!authorized);if(!authorized)password.value=''}
function save(data){session=data;try{if(data)sessionStorage.setItem(storageKey,JSON.stringify(data));else sessionStorage.removeItem(storageKey)}catch{}show(!!data)}
async function api(path,token,body){const response=await fetch(url+path,{method:body?'POST':'GET',headers:{'apikey':key,'Authorization':'Bearer '+(token||key),'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,cache:'no-store'});const data=await response.json().catch(()=>({}));if(!response.ok)throw Error(data.msg||data.error_description||data.message||'Authentication failed');return data}
async function check(){try{const saved=JSON.parse(sessionStorage.getItem(storageKey)||'null');if(saved?.access_token){const user=await api('/auth/v1/user',saved.access_token);if(user?.id){save(saved);return}}}catch{}save(null)}
form.addEventListener('submit',async e=>{e.preventDefault();const button=form.querySelector('button');button.disabled=true;status.textContent='Signing in…';try{const data=await api('/auth/v1/token?grant_type=password',null,{email:email.value.trim(),password:password.value});if(!data.access_token)throw Error('No access token received');save(data);status.textContent='';password.value=''}catch(err){status.textContent='Could not sign in. Check your email and password.'}finally{button.disabled=false}});
logout.addEventListener('click',async()=>{const token=session?.access_token;save(null);if(token)try{await api('/auth/v1/logout',token,{})}catch{}});
show(false);void check();
})();