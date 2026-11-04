(()=>{
'use strict';
const $=id=>document.getElementById(id);
const request=(location.hash.match(/^#request=([A-Za-z0-9_-]{24,40})$/)||[])[1]||'';
const api='https://itamaros-store-api.onrender.com/api/connect/pair/approve';
const authKey='itamaros.web.session.v1';
const status=message=>{$('status').textContent=message};
if(!request){status('Invalid or missing QR request. Scan the code again.');return}
$('pairCode').textContent=request.slice(0,6).toUpperCase();
$('nativeLink').href='itamaros://desktop?request='+encodeURIComponent(request);
let token=null;
try{token=JSON.parse(sessionStorage.getItem(authKey)||'null')?.access_token||null}catch{}
if(!token){
 $('approve').hidden=true;
 $('identity').textContent='Sign in to ItamarOS in this browser first, then scan the QR again.';
 status('No active ItamarOS browser session.');
 const link=document.createElement('a');link.href='/';link.textContent='Sign in to ItamarOS';$('status').append(document.createElement('br'),link);
 return;
}
$('identity').textContent='You are approving a sign-in on another device. Confirm that the QR and request identifier match the device you control.';
$('approve').disabled=false;
$('approve').hidden=false;
$('approve').textContent='Approve Cloud Climb / ItamarOS sign-in';
$('approve').addEventListener('click',async()=>{
 if(!window.confirm('Only approve the QR currently displayed on your own Cloud Climb or ItamarOS device. This grants that device access to your account until the temporary session expires. Continue?'))return;
 $('approve').disabled=true;
 status('Checking your account and approving…');
 try{
  const response=await fetch(api,{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({requestId:request}),cache:'no-store'});
  const result=await response.json();
  if(!response.ok)throw Error(result.error||'Approval failed');
  status('Approved. Return to Cloud Climb; it should finish connecting shortly.');
  $('approve').hidden=true;
 }catch(error){status(error.message||'Approval failed.');$('approve').disabled=false}
});
})();