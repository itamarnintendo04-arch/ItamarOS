(()=>{
'use strict';
const $=id=>document.getElementById(id);
const request=decodeURIComponent((location.hash.match(/^#request=([A-Za-z0-9_-]{24,40})$/)||[])[1]||'');
const api='https://itamaros-store-api.onrender.com/api/connect/pair/approve';
const config=window.ITAMAR_CONNECT||{};
const setStatus=(message)=>{$('status').textContent=message};
if(!request){setStatus('Invalid or missing QR request. Scan the code again.');return}
$('pairCode').textContent=request.slice(0,6).toUpperCase();
$('nativeLink').href='itamaros://desktop?request='+encodeURIComponent(request);
const supabase=window.supabase.createClient(config.url,config.publishableKey,{
 auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:false,storageKey:'itamaros-connect-web-auth'}
});
let signedIn=false;
async function check(){
 try{
  const {data,error}=await supabase.auth.getUser();
  if(error||!data.user||!data.user.phone_confirmed_at){
   setStatus('First sign in with your verified phone in ItamarConnect in this browser.');
   return;
  }
  signedIn=true;
  $('identity').textContent='Signed-in account: '+(data.user.email||'Verified phone account');
  $('approve').disabled=false;
  setStatus('Review the code on your computer, then tap Approve.');
 }catch{setStatus('Authentication unavailable. Try again.')}
}
$('approve').addEventListener('click',async()=>{
 if(!signedIn)return;
 $('approve').disabled=true;
 try{
  const {data,error}=await supabase.auth.getSession();
  if(error||!data.session)throw Error('Sign in again on this phone.');
  const response=await fetch(api,{
   method:'POST',
   headers:{'Content-Type':'application/json','Authorization':'Bearer '+data.session.access_token},
   body:JSON.stringify({requestId:request})
  });
  const result=await response.json();
  if(!response.ok)throw Error(result.error||'Approval failed');
  setStatus('Approved. Return to your computer to continue.');
 }catch(e){
  setStatus(e.message||'Approval failed.');$('approve').disabled=false;
 }
});
void check();
})();
