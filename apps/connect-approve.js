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
// Browser-based approval cannot enforce the native device credential / Face ID.
// Keep this page as a safe launcher for the installed ItamarOS app.
$('approve').disabled=true;
$('approve').hidden=true;
$('identity').textContent='Open the ItamarOS app on your trusted phone to approve.';
setStatus('Face ID or the device lock is required in the installed app. Browser approval is disabled.');
})();
