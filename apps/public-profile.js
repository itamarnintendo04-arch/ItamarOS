(()=>{'use strict';
const $=id=>document.getElementById(id),cfg=window.ITAMAR_CONNECT||{};
const validURL=/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/i.test(cfg.url||'');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const msg=x=>{$('status').textContent=String(x||'').slice(0,350)};
let data=null;
async function lookup(id){
 $('profile').hidden=true;data=null;
 if(!uuid.test(id)){msg('Enter a valid ItamarOS user ID.');return}
 if(!validURL){msg('Profile service is not configured.');return}
 const response=await fetch(cfg.url.replace(/\/$/,'')+'/functions/v1/itamar-public-profile?id='+encodeURIComponent(id),{
  headers:{apikey:cfg.publishableKey||''},referrerPolicy:'no-referrer'
 });
 const profile=await response.json();
 if(!response.ok)throw Error(profile.error||'Profile unavailable');
 data=profile;
 $('id').value=profile.id;
 $('name').textContent=profile.display_name;
 $('username').textContent='@'+profile.username;
 $('about').textContent=profile.about||'';
 $('userID').textContent=profile.id;
 const badge=$('badge');
 badge.hidden=!profile.badge;
 badge.className='verified '+(profile.badge==='green'?'green':'blue');
 badge.textContent='✓';badge.title=profile.badge==='green'?'ItamarOS official administrator':'ItamarOS verified';
 const picture=$('avatar');
 picture.hidden=!profile.avatar_url;
 if(profile.avatar_url)picture.src=profile.avatar_url;
 const qr=$('qr');qr.replaceChildren();
 if(window.QRCode){
  new window.QRCode(qr,{text:profile.profile_url,width:200,height:200,
   correctLevel:window.QRCode.CorrectLevel.M});
 }else{qr.textContent='QR preview unavailable. Use Copy profile link.'}
 $('profile').hidden=false;msg('Public profile loaded.');
 history.replaceState(null,'','?id='+encodeURIComponent(profile.id));
}
$('lookup').onsubmit=e=>{e.preventDefault();lookup($('id').value.trim()).catch(e=>msg(e.message))};
$('copyID').onclick=()=>data&&navigator.clipboard.writeText(data.id).then(()=>msg('ID copied.')).catch(()=>msg('Clipboard unavailable.'));
$('copyLink').onclick=()=>data&&navigator.clipboard.writeText(data.profile_url).then(()=>msg('Profile URL copied.')).catch(()=>msg('Clipboard unavailable.'));
const param=new URLSearchParams(location.search).get('id');
if(param)lookup(param).catch(e=>msg(e.message));
})();